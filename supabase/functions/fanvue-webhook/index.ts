/// <reference lib="deno.ns" />
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { crypto } from "https://deno.land/std@0.177.0/crypto/mod.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

/**
 * fanvue-webhook
 * 
 * Purpose: Handle Fanvue webhooks for all creators
 * Auth: Verify JWT OFF (Fanvue server has no JWT)
 * 
 * Creator Detection (in order):
 * 1. ?creatorId=<uuid> in URL (optional, backwards compatible)
 * 2. recipientUuid from webhook payload → lookup via fanvue_creator_id in creators table
 * 3. Webhook signature matching against all stored webhook secrets
 * 
 * Signature: Uses per-creator webhook secret from creator_integrations
 * 
 * Fanvue Signature Format:
 * Header: X-Fanvue-Signature: t=<timestamp>,v0=<signature>
 * Signed payload: `${timestamp}.${rawBody}`
 * Expected: HMAC-SHA256(secret, signedPayload) in hex
 */

const CORS_HEADERS = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-fanvue-signature",
    "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
};

const SIGNATURE_TOLERANCE_SECONDS = 300; // 5 minutes

interface WebhookPayload {
    event: string;
    data: Record<string, unknown>;
}

/**
 * Calculate human-like delay for responses
 * If pending_count is high, delay increases slightly (more realistic)
 * Formula: random(30..80) + min(pending_count * 5, 40) seconds
 */
function calculateHumanDelay(pendingCount: number = 0): number {
    const baseDelay = 30 + Math.random() * 50; // 30-80 seconds
    const pendingBonus = Math.min(pendingCount * 5, 40); // Max +40s for many messages
    return Math.round(baseDelay + pendingBonus);
}

/**
 * Determine fan stage based on message count and spend
 */
function determineFanStage(msgCount: number, totalSpend: number): string {
    if (totalSpend >= 100) return 'vip';
    if (totalSpend > 0) return 'post_purchase';
    if (msgCount >= 20) return 'sales';
    if (msgCount >= 10) return 'flirty';
    if (msgCount >= 5) return 'warmup';
    return 'new';
}

function isValidUUID(str: string): boolean {
    const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    return uuidRegex.test(str);
}

function parseSignatureHeader(header: string): { timestamp: string; signature: string } | null {
    // Format: t=<timestamp>,v0=<signature>
    const parts: Record<string, string> = {};
    for (const part of header.split(",")) {
        const [key, value] = part.split("=", 2);
        if (key && value) {
            parts[key.trim()] = value.trim();
        }
    }

    if (parts.t && parts.v0) {
        return { timestamp: parts.t, signature: parts.v0 };
    }
    return null;
}

async function verifyFanvueSignature(
    rawBody: string,
    signatureHeader: string,
    webhookSecret: string
): Promise<{ valid: boolean; error?: string }> {
    if (!webhookSecret) {
        console.warn("⚠️ No webhook secret configured - skipping verification (DEV MODE)");
        return { valid: true };
    }

    if (!signatureHeader) {
        return { valid: false, error: "Missing X-Fanvue-Signature header" };
    }

    const parsed = parseSignatureHeader(signatureHeader);
    if (!parsed) {
        return { valid: false, error: "Invalid signature header format" };
    }

    const { timestamp, signature } = parsed;

    // Check timestamp tolerance
    const timestampNum = parseInt(timestamp, 10);
    if (isNaN(timestampNum)) {
        return { valid: false, error: "Invalid timestamp in signature" };
    }

    const now = Math.floor(Date.now() / 1000);
    if (Math.abs(now - timestampNum) > SIGNATURE_TOLERANCE_SECONDS) {
        return { valid: false, error: `Timestamp too old (${now - timestampNum}s difference)` };
    }

    // Compute expected signature
    const signedPayload = `${timestamp}.${rawBody}`;

    const key = await crypto.subtle.importKey(
        "raw",
        new TextEncoder().encode(webhookSecret),
        { name: "HMAC", hash: "SHA-256" },
        false,
        ["sign"]
    );

    const signedBuffer = await crypto.subtle.sign(
        "HMAC",
        key,
        new TextEncoder().encode(signedPayload)
    );

    const expectedSignature = Array.from(new Uint8Array(signedBuffer))
        .map((b) => b.toString(16).padStart(2, "0"))
        .join("");

    // Constant-time comparison
    if (signature.length !== expectedSignature.length) {
        return { valid: false, error: "Signature length mismatch" };
    }

    let diff = 0;
    for (let i = 0; i < signature.length; i++) {
        diff |= signature.charCodeAt(i) ^ expectedSignature.charCodeAt(i);
    }

    if (diff !== 0) {
        return { valid: false, error: "Signature mismatch" };
    }

    return { valid: true };
}

serve(async (req) => {
    console.log("➡️ fanvue-webhook hit (v66-CLEAN | DEPLOY-1436)", req.method, req.url);

    // Handle CORS preflight
    if (req.method === "OPTIONS") {
        return new Response("ok", { headers: CORS_HEADERS });
    }

    // Health check endpoint
    if (req.method === "GET") {
        return new Response(
            JSON.stringify({ ok: true, message: "Webhook endpoint ready" }),
            { status: 200, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
        );
    }

    if (req.method !== "POST") {
        return new Response(
            JSON.stringify({ error: "Method not allowed" }),
            { status: 405, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
        );
    }

    // Get environment variables (global infrastructure only)
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !serviceRoleKey) {
        console.error("❌ Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
        return new Response(
            JSON.stringify({ error: "Server configuration error" }),
            { status: 500, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
        );
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey);

    try {
        const rawBody = await req.text();

        // Parse payload first to potentially extract creator info
        let payload: WebhookPayload;
        try {
            payload = JSON.parse(rawBody);
        } catch {
            console.error("❌ Invalid JSON payload");
            return new Response(
                JSON.stringify({ error: "Invalid JSON payload" }),
                { status: 400, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
            );
        }

        // Limited logging to prevent 503 errors
        console.log("📦 Payload keys:", Object.keys(payload).join(", "));

        // 1. Determine creatorId - try URL param first, then extract from payload
        const url = new URL(req.url);
        let creatorId = url.searchParams.get("creatorId");

        if (!creatorId) {
            // Try to find creator from payload
            // Fanvue sends recipientUuid which is the creator's Fanvue ID
            const fanvueCreatorId = payload.recipientUuid ||
                payload.recipient?.uuid ||
                payload.creatorUuid ||
                payload.creator?.uuid;

            if (fanvueCreatorId) {
                console.log("🔍 Looking up creator by Fanvue ID:", fanvueCreatorId);

                // Look up creator by fanvue_creator_id
                const { data: creator, error: creatorError } = await supabase
                    .from("creators")
                    .select("id")
                    .eq("fanvue_creator_id", String(fanvueCreatorId))
                    .maybeSingle();

                if (creatorError) {
                    console.error("❌ Creator lookup error:", creatorError);
                }

                if (creator) {
                    creatorId = creator.id;
                    console.log("✅ Found creator by Fanvue ID:", creatorId);
                }
            }
        }

        // Still no creatorId? Try to match by webhook secret (signature validation will find the right one)
        if (!creatorId) {
            console.log("🔍 No creator ID found, trying to match by webhook signature...");

            const signatureHeader = req.headers.get("x-fanvue-signature") ||
                req.headers.get("X-Fanvue-Signature") || "";

            if (signatureHeader) {
                // Get all integrations and try each one's webhook secret
                const { data: integrations } = await supabase
                    .from("creator_integrations")
                    .select("creator_id, fanvue_webhook_secret")
                    .eq("integration_type", "fanvue")
                    .not("fanvue_webhook_secret", "is", null);

                if (integrations) {
                    for (const integration of integrations) {
                        if (!integration.fanvue_webhook_secret) continue;

                        const verification = await verifyFanvueSignature(
                            rawBody,
                            signatureHeader,
                            integration.fanvue_webhook_secret
                        );

                        if (verification.valid) {
                            creatorId = integration.creator_id;
                            console.log("✅ Found creator by webhook signature match:", creatorId);
                            break;
                        }
                    }
                }
            }
        }

        if (!creatorId) {
            console.error("❌ Could not determine creator - no URL param and no match in payload/signature");
            return new Response(
                JSON.stringify({
                    error: "Could not determine creator",
                    hint: "Add ?creatorId=UUID to URL or ensure fanvue_creator_id is set in DB",
                    payload_keys: Object.keys(payload)
                }),
                { status: 400, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
            );
        }

        if (!isValidUUID(creatorId)) {
            console.error("❌ Invalid creatorId format:", creatorId);
            return new Response(
                JSON.stringify({ error: "Invalid creatorId format (must be UUID)" }),
                { status: 400, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
            );
        }

        // 2. Get per-creator webhook secret from DB
        const { data: integration, error: integrationError } = await supabase
            .from("creator_integrations")
            .select("fanvue_webhook_secret")
            .eq("creator_id", creatorId)
            .eq("integration_type", "fanvue")
            .single();

        if (integrationError || !integration) {
            console.error("❌ Integration not found for creator:", creatorId);
            return new Response(
                JSON.stringify({ error: "Creator integration not found" }),
                { status: 404, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
            );
        }

        const webhookSecret = integration.fanvue_webhook_secret || "";

        // 3. Verify webhook signature
        const signatureHeader = req.headers.get("x-fanvue-signature") ||
            req.headers.get("X-Fanvue-Signature") || "";

        const verification = await verifyFanvueSignature(rawBody, signatureHeader, webhookSecret);

        if (!verification.valid) {
            console.error("❌ Invalid webhook signature:", verification.error);

            // Update integration with error
            await supabase
                .from("creator_integrations")
                .update({
                    last_webhook_error: `Signature validation failed: ${verification.error}`,
                    updated_at: new Date().toISOString(),
                })
                .eq("creator_id", creatorId)
                .eq("integration_type", "fanvue");

            return new Response(
                JSON.stringify({ error: "Invalid webhook signature", details: verification.error }),
                { status: 401, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
            );
        }

        console.log("✅ Webhook signature verified for creator:", creatorId);

        // 4. Payload already parsed earlier - just log event info
        console.log("📨 Webhook event:", payload.event, "for creator:", creatorId);
        console.log("📋 Payload keys:", Object.keys(payload));

        // 5. Update last webhook timestamp
        await supabase
            .from("creator_integrations")
            .update({
                last_webhook_at: new Date().toISOString(),
                last_webhook_error: null,
                updated_at: new Date().toISOString(),
            })
            .eq("creator_id", creatorId)
            .eq("integration_type", "fanvue");

        // Detect event type from payload structure (Fanvue doesn't use 'event' field)
        // Fanvue sends: { message: {...}, sender: {...}, recipientUuid, messageUuid, timestamp }
        const hasMessage = payload.message !== undefined;
        const hasTransaction = payload.transaction !== undefined;

        // Determine event type from payload structure
        let eventType = "unknown";
        if (hasMessage) {
            eventType = "message.received";
        } else if (hasTransaction) {
            eventType = "transaction.created";
        } else if (payload.event) {
            eventType = payload.event; // Fallback for potential other formats
        }

        console.log("🎯 Detected event type:", eventType);

        // 6. Handle Message Events
        if (eventType === "message.received" || hasMessage) {
            // Extract data from Fanvue format
            const messageData = payload.message || {};
            const senderData = payload.sender || {};

            const fanvueFanId = String(senderData.uuid || senderData.id || payload.senderUuid || "");
            let messageContent = String(messageData.text || messageData.content || "");
            const messageId = String(payload.messageUuid || messageData.uuid || messageData.id || "");

            // Handle Media attachments - ROBUST detection
            const images = messageData.images || [];
            const videos = messageData.videos || [];
            const hasMediaFlag = messageData.hasMedia === true;
            const mediaType = messageData.mediaType;

            // Determine if this message has media (any of these conditions)
            const hasMedia = hasMediaFlag ||
                mediaType !== undefined ||
                images.length > 0 ||
                videos.length > 0;

            // Add system hints for media (only if we detected some)
            if (images.length > 0) {
                messageContent += `\n[System: User sent ${images.length} image(s). You cannot see them, but acknowledge receiving them playfully.]`;
            }
            if (videos.length > 0) {
                messageContent += `\n[System: User sent ${videos.length} video(s). You cannot see them, but acknowledge receiving them playfully.]`;
            }
            // Fallback: hasMedia flag or mediaType but no images/videos array
            if (hasMedia && images.length === 0 && videos.length === 0 && !messageContent.includes("[System:")) {
                messageContent += `\n[System: User sent media attachment. You cannot see it, but acknowledge receiving it playfully.]`;
            }

            // If message text is empty but has media, use placeholder
            if (!messageContent.trim() && hasMedia) {
                messageContent = "[User sent media]";
            }

            console.log("📎 Media detection:", { hasMedia, hasMediaFlag, mediaType, imagesCount: images.length, videosCount: videos.length });

            // Extract both name fields from Fanvue
            const senderHandle = String(senderData.handle || senderData.username || "");
            const senderDisplayName = String(senderData.displayName || senderData.name || "");
            // Fallback: use one if the other is empty
            const finalUsername = senderHandle || senderDisplayName || "unknown";
            const finalDisplayName = senderDisplayName || senderHandle || "Unknown";

            console.log("📩 Message from:", finalUsername, "(", finalDisplayName, ") content:", messageContent.substring(0, 50));

            if (!fanvueFanId) {
                console.warn("⚠️ No fan ID in message event - sender:", JSON.stringify(senderData));
                return new Response(
                    JSON.stringify({ received: true, warning: "No fan ID in message" }),
                    { status: 200, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
                );
            }

            // Get existing fan to update counters
            const { data: existingFan } = await supabase
                .from("fans")
                .select("id, msg_count_inbound, total_spend, stage")
                .eq("creator_id", creatorId)
                .eq("fanvue_fan_id", fanvueFanId)
                .maybeSingle();

            let fan: { id: string; stage: string };
            let newMsgCount: number;

            if (existingFan) {
                // UPDATE existing fan - increment counter
                newMsgCount = (existingFan.msg_count_inbound || 0) + 1;
                const totalSpend = existingFan.total_spend || 0;
                const newStage = determineFanStage(newMsgCount, totalSpend);

                const { error: updateError } = await supabase
                    .from("fans")
                    .update({
                        username: finalUsername,
                        display_name: finalDisplayName,
                        msg_count_inbound: newMsgCount,
                        stage: newStage,
                        updated_at: new Date().toISOString(),
                    })
                    .eq("id", existingFan.id);

                if (updateError) {
                    console.error("❌ Fan update error:", updateError);
                    // Continue anyway with existing fan data
                }

                fan = { id: existingFan.id, stage: newStage };
                console.log("✅ Fan updated:", fan.id, "| Stage:", fan.stage, "| Msg#:", newMsgCount);
            } else {
                // INSERT new fan
                newMsgCount = 1;
                const newStage = "new";

                const { data: newFan, error: insertError } = await supabase
                    .from("fans")
                    .insert({
                        creator_id: creatorId,
                        fanvue_fan_id: fanvueFanId,
                        username: finalUsername,
                        display_name: finalDisplayName,
                        msg_count_inbound: 1,
                        stage: newStage,
                    })
                    .select("id, stage")
                    .single();

                if (insertError || !newFan) {
                    console.error("❌ Fan insert error:", insertError);
                    throw insertError || new Error("Failed to create fan");
                }

                fan = newFan;
                console.log("✅ Fan created:", fan.id, "| Stage:", fan.stage);
            }

            // 1. ALWAYS save inbound message first
            const { error: msgError } = await supabase.from("messages").insert({
                creator_id: creatorId,
                fan_id: fan.id,
                direction: "inbound",
                text: messageContent,
                provider_message_id: messageId,
                has_media: hasMedia,
            });

            if (msgError) {
                console.error("❌ Message insert error:", msgError);
            } else {
                console.log("✅ Message saved");
            }

            // Update conversation state
            await supabase.from("conversation_state").upsert(
                {
                    creator_id: creatorId,
                    fan_id: fan.id,
                    last_inbound_at: new Date().toISOString(),
                    updated_at: new Date().toISOString(),
                },
                { onConflict: "fan_id,creator_id" }
            );

            // 2. CHECK: Is there already a queued reply job for this fan?
            const { data: existingJob } = await supabase
                .from("jobs_queue")
                .select("id, pending_count, payload")
                .eq("creator_id", creatorId)
                .eq("fan_id", fan.id)
                .eq("job_type", "reply")
                .eq("status", "queued")
                .maybeSingle();

            const now = new Date();
            const nowIso = now.toISOString();

            if (existingJob) {
                // === DEBOUNCE: Update existing job ===
                const newPendingCount = (existingJob.pending_count || 0) + 1;
                const newDelay = calculateHumanDelay(newPendingCount);
                const newRunAt = new Date(now.getTime() + newDelay * 1000).toISOString();

                await supabase
                    .from("jobs_queue")
                    .update({
                        run_at: newRunAt,
                        last_message_at: nowIso,
                        pending_count: newPendingCount,
                        payload: {
                            ...existingJob.payload,
                            last_message_id: messageId,
                            has_media: hasMedia || existingJob.payload?.has_media,
                            fan_stage: fan.stage,
                        },
                    })
                    .eq("id", existingJob.id);

                console.log(`🔄 Debounced: Job ${existingJob.id} | pending: ${newPendingCount} | run_at: +${newDelay}s`);
                return new Response(
                    JSON.stringify({
                        received: true,
                        debounced: true,
                        job_id: existingJob.id,
                        pending_count: newPendingCount,
                        delay_seconds: newDelay,
                    }),
                    { status: 200, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
                );
            }

            // 3. CREATE NEW JOB (no existing queued job)
            const shouldQueue = messageContent.trim().length > 0 || hasMedia;

            if (!shouldQueue) {
                console.log("⏭️ No text and no media, skipping job creation");
                return new Response(
                    JSON.stringify({ received: true, skipped: true, reason: "empty_message" }),
                    { status: 200, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
                );
            }

            // Calculate initial delay (no pending messages yet)
            const delaySeconds = calculateHumanDelay(0);
            const runAt = new Date(now.getTime() + delaySeconds * 1000).toISOString();

            console.log(`🕐 New job | delay: ${delaySeconds}s | run_at: ${runAt}`);

            const { error: jobError } = await supabase.from("jobs_queue").insert({
                creator_id: creatorId,
                fan_id: fan.id,
                job_type: "reply",
                status: "queued",
                run_at: runAt,
                last_message_at: nowIso,
                pending_count: 0,
                payload: {
                    message_id: messageId,
                    fan_message: messageContent,
                    fan_username: finalUsername,
                    fan_display_name: finalDisplayName,
                    fanvue_fan_id: fanvueFanId,
                    has_media: hasMedia,
                    fan_stage: fan.stage,
                },
            });

            if (jobError) {
                console.error("❌ Job queue error:", jobError);
            } else {
                console.log("✅ Reply job created");
            }

            return new Response(
                JSON.stringify({
                    received: true,
                    creator_id: creatorId,
                    fan_id: fan.id,
                    job_enqueued: !jobError,
                    delay_seconds: delaySeconds,
                    fan_stage: fan.stage,
                }),
                { status: 200, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
            );
        }

        // 7. Handle Transaction Events
        if (eventType === "transaction.created" || eventType === "transaction.completed" || eventType === "transaction" || hasTransaction) {
            const txData = payload.transaction || payload.data || payload;
            const fanvueFanId = String(txData.userId || txData.fan_id || txData.senderId || payload.senderUuid || "");
            const transactionId = String(txData.id || txData.transactionId || "");
            const amount = Number(txData.amount) || 0;
            const transactionType = String(txData.type || "tip");

            if (!fanvueFanId) {
                return new Response(
                    JSON.stringify({ received: true, warning: "No fan ID in transaction" }),
                    { status: 200, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
                );
            }

            // Upsert Fan
            const { data: fan } = await supabase
                .from("fans")
                .upsert(
                    {
                        creator_id: creatorId,
                        fanvue_fan_id: fanvueFanId,
                        updated_at: new Date().toISOString(),
                    },
                    { onConflict: "creator_id,fanvue_fan_id" }
                )
                .select()
                .single();

            if (fan) {
                // Save transaction
                await supabase.from("transactions").insert({
                    creator_id: creatorId,
                    fan_id: fan.id,
                    fanvue_transaction_id: transactionId,
                    amount: amount,
                    type: transactionType,
                    created_at: String(txData.timestamp || txData.created_at || new Date().toISOString()),
                });

                console.log("✅ Transaction saved:", transactionId);

                // Enqueue followup job
                await supabase.from("jobs_queue").insert({
                    creator_id: creatorId,
                    fan_id: fan.id,
                    type: "followup",
                    payload: {
                        type: "thank_you",
                        transaction_id: transactionId,
                        amount: amount,
                    },
                });
            }

            return new Response(
                JSON.stringify({ received: true, creator_id: creatorId }),
                { status: 200, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
            );
        }

        // 8. Handle Test Event (from Fanvue UI)
        if (eventType === "test" || eventType === "webhook.test") {
            console.log("✅ Test webhook received");
            return new Response(
                JSON.stringify({ received: true, event: "test", creator_id: creatorId }),
                { status: 200, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
            );
        }

        // 9. Unknown event - still return 200 to avoid retries
        console.warn("⚠️ Unknown webhook event:", eventType);
        return new Response(
            JSON.stringify({ received: true, event: "unknown", eventType: eventType }),
            { status: 200, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
        );

    } catch (error) {
        console.error("❌ Webhook Error:", error);

        // Return 200 to prevent Fanvue retries
        return new Response(
            JSON.stringify({ error: String(error), received: false }),
            { status: 200, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
        );
    }
});
