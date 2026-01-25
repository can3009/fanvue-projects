// supabase/functions/jobs-worker/index.ts
/// <reference lib="deno.ns" />

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

import { createSupabaseServiceClient } from "../_shared/supabaseClient.ts";
import { getValidAccessToken } from "../_shared/tokenManager.ts";
import { generateReply, ChatMessage } from "../_shared/llmClient.ts";
import { sendFanvueMessage, markChatAsRead } from "../_shared/fanvueClient.ts";
import { sendMassMessage, MassMessageRequest } from "../_shared/fanvueRestClient.ts";
import { CreatorSettings, CORS_HEADERS } from "../_shared/types.ts";

type JobRow = {
    id: string;
    job_type: "reply" | "followup" | "broadcast" | string;
    status: "queued" | "processing" | "completed" | "failed" | string;
    run_at: string;
    attempts: number | null;
    last_error: string | null;
    created_at: string;

    creator_id: string;
    fan_id: string | null;

    payload: any;
};

// --- Helper: Supabase calls sollen nicht still fehlschlagen (RLS/Schema/Netzwerk) ---
function throwIfSupabaseError(label: string, error: any) {
    if (error) {
        throw new Error(`${label}: ${error.message ?? String(error)}`);
    }
}

/**
 * Manual auth (for Verify JWT OFF deploy).
 * Accepts:
 * - Authorization: Bearer <JOBS_WORKER_SECRET>  (Cron/external)
 * - Authorization: Bearer <SUPABASE_USER_JWT>   (Admin UI calls)
 */
function getBearerToken(req: Request): string | null {
    const auth = req.headers.get("authorization") || "";
    if (!auth.toLowerCase().startsWith("bearer ")) return null;
    const token = auth.slice("bearer ".length).trim();
    return token.length > 0 ? token : null;
}

/**
 * Authorization check:
 * - Option 1: JOBS_WORKER_SECRET (for Cron/external calls)
 * - Option 2: Valid Supabase JWT (for Admin App calls) - verified via auth.getUser()
 */
async function isAuthorized(req: Request): Promise<boolean> {
    const token = getBearerToken(req);
    if (!token) return false;

    // Option 1: JOBS_WORKER_SECRET (Cron / extern)
    const workerSecret = (Deno.env.get("JOBS_WORKER_SECRET") || "").trim();
    if (workerSecret && token === workerSecret) return true;

    // Option 2: Verify Supabase JWT via auth.getUser()
    const supabaseUrl =
        Deno.env.get("SUPABASE_URL") || Deno.env.get("PROJECT_URL");
    const anonKey =
        Deno.env.get("SUPABASE_ANON_KEY") || Deno.env.get("ANON_KEY");

    if (!supabaseUrl || !anonKey) return false;

    try {
        const supabaseForAuth = createClient(supabaseUrl, anonKey, {
            global: { headers: { Authorization: `Bearer ${token}` } },
        });

        const { data, error } = await supabaseForAuth.auth.getUser();
        if (error || !data?.user) return false;

        return true;
    } catch {
        return false;
    }
}

// Generate unique media fallback response via LLM
async function generateMediaFallbackResponse(
    settings: CreatorSettings,
): Promise<string> {
    const systemPrompt =
        `Du bist ein flirty Chat-Partner. Der User hat dir ein Bild/Video geschickt, aber du kannst es technisch NICHT sehen - du siehst nur ein Anhang-Symbol.

WICHTIG:
- Du darfst NIEMALS so tun als hättest du das Bild gesehen
- Frag spielerisch/neugierig was drauf ist
- Sei kreativ und variiere deine Antworten - nie zweimal das gleiche sagen
- Kurz halten (1-2 Sätze max)
- Passend zum Persona: ${settings.persona_name || "flirty creator"}
- Ton: ${settings.tone || "playful, teasing"}

Beispiel-Vibes (aber erfinde was NEUES):
- Neugierig fragen was drauf ist
- Spielerisch beschweren dass du es nicht öffnen kannst
- Flirty nachfragen ob es cute oder spicy ist`;

    const response = await generateReply(
        [{ role: "user", content: "[User hat ein Bild/Video geschickt ohne Text]" }],
        settings,
        systemPrompt,
    );
    return response;
}

function isMediaOnlyMessage(text: string | null | undefined): boolean {
    if (!text) return true;
    const trimmed = text.trim();
    if (trimmed === "") return true;
    if (trimmed === "[User sent media]") return true;
    if (trimmed.match(/^\[System:.*media.*\]$/i)) return true;
    return false;
}

/**
 * Pro Request: mehrere Jobs verarbeiten (Batch).
 * Die UI ruft diese Function in einer Loop wiederholt auf, bis du "Abbrechen" drückst.
 */
serve(async (req) => {
    if (req.method === "OPTIONS") {
        return new Response("ok", { headers: CORS_HEADERS });
    }

    if (req.method !== "POST") {
        return new Response(JSON.stringify({ error: "Method not allowed" }), {
            status: 405,
            headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
        });
    }

    // If you deploy with --no-verify-jwt, you MUST protect the endpoint yourself:
    if (!(await isAuthorized(req))) {
        return new Response(JSON.stringify({ error: "Unauthorized" }), {
            status: 401,
            headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
        });
    }

    const supabase = createSupabaseServiceClient();

    // Batch-Parameter (optional aus Body)
    let batchSize = 20;
    let maxMillis = 25_000; // Time budget, damit Supabase nicht killt

    try {
        const body = await req.json().catch(() => ({}));
        if (typeof body?.batchSize === "number") batchSize = body.batchSize;
        if (typeof body?.maxMillis === "number") maxMillis = body.maxMillis;
    } catch {
        // ignore
    }

    const deadline = Date.now() + Math.max(5_000, Math.min(maxMillis, 50_000));

    let processed = 0;
    let completed = 0;
    let failed = 0;
    let skipped = 0;

    const processedJobIds: string[] = [];
    const errors: Array<{ jobId: string | null; error: string }> = [];

    while (processed < batchSize && Date.now() < deadline) {
        // WICHTIG: currentJobId erst setzen, NACHDEM der Job erfolgreich "geclaimed" wurde
        let currentJobId: string | null = null;

        try {
            const nowIso = new Date().toISOString();

            // 1) Nächsten fälligen Job lesen (nur lesen)
            const { data: job, error: fetchError } = await supabase
                .from("jobs_queue")
                .select("*")
                .eq("status", "queued")
                .lte("run_at", nowIso)
                .order("run_at", { ascending: true })
                .limit(1)
                .maybeSingle<JobRow>();

            throwIfSupabaseError("❌ Job fetch error", fetchError);

            if (!job) {
                // keine Jobs -> Batch Ende
                break;
            }

            // 2) Atomisches Claiming
            const { data: claimed, error: claimErr } = await supabase
                .from("jobs_queue")
                .update({ status: "processing" })
                .eq("id", job.id)
                .eq("status", "queued")
                .select("id")
                .maybeSingle();

            throwIfSupabaseError("❌ Job claim error", claimErr);

            if (!claimed) {
                // jemand anders hat ihn geclaimed -> nächste Runde
                continue;
            }

            currentJobId = job.id;
            processedJobIds.push(job.id);
            processed++;

            console.log(`🔄 Processing Job ${job.id} (type: ${job.job_type})`);

            // =========================
            // JOB PROCESSING (dein Code)
            // =========================

            if (job.job_type === "reply") {
                const creator_id = job.creator_id;
                const fan_id = job.fan_id;

                if (!fan_id) throw new Error("Job is missing fan_id (NULL). Fix jobs_queue row.");

                const fan_message = job.payload?.fan_message;
                const hasMedia = job.payload?.has_media === true;

                if (!fan_message && !hasMedia) {
                    throw new Error("Job payload missing fan_message and no media");
                }

                // CHECK: Have we already replied?
                const { data: recentOutbound, error: recentErr } = await supabase
                    .from("messages")
                    .select("id, created_at")
                    .eq("creator_id", creator_id)
                    .eq("fan_id", fan_id)
                    .eq("direction", "outbound")
                    .gte("created_at", job.created_at)
                    .limit(1)
                    .maybeSingle();

                throwIfSupabaseError("Messages recentOutbound select failed", recentErr);

                if (recentOutbound) {
                    console.log("⏭️ Already replied to this conversation, skipping");
                    const { error: updErr } = await supabase
                        .from("jobs_queue")
                        .update({ status: "completed", last_error: "skipped:duplicate" })
                        .eq("id", job.id)
                        .eq("status", "processing");

                    throwIfSupabaseError("jobs_queue update skipped failed", updErr);

                    skipped++;
                    completed++;
                    continue;
                }

                // Creator settings
                const { data: creator, error: creatorError } = await supabase
                    .from("creators")
                    .select("settings_json, is_active")
                    .eq("id", creator_id)
                    .single();

                throwIfSupabaseError("Creator select failed", creatorError);

                if (!creator?.is_active) throw new Error("Creator is not active");

                // OAuth token
                const { token: accessToken, error: tokenError } = await getValidAccessToken(
                    supabase,
                    creator_id,
                );

                if (tokenError || !accessToken) {
                    throw new Error(`No access token: ${tokenError || "Token unavailable"}`);
                }

                // Mark chat as read
                const fanvueFanId = job.payload?.fanvue_fan_id;
                if (fanvueFanId) {
                    try {
                        await markChatAsRead(fanvueFanId, accessToken);
                    } catch (readError) {
                        console.warn("⚠️ Could not mark chat as read:", readError);
                    }
                }

                // Conversation history
                const { data: messages, error: msgErr } = await supabase
                    .from("messages")
                    .select("direction, text, created_at, has_media")
                    .eq("creator_id", creator_id)
                    .eq("fan_id", fan_id)
                    .order("created_at", { ascending: false })
                    .limit(10);

                throwIfSupabaseError("Messages select failed", msgErr);

                const lastInbound = (messages || []).find((m: any) => m.direction === "inbound");

                // Media-only fallback
                if (lastInbound?.has_media === true && isMediaOnlyMessage(lastInbound.text)) {
                    console.log("📎 Media-only message detected");

                    const { data: fanData, error: fanError } = await supabase
                        .from("fans")
                        .select("fanvue_fan_id")
                        .eq("id", fan_id)
                        .single();

                    throwIfSupabaseError("Fan select failed", fanError);

                    if (!fanData?.fanvue_fan_id) throw new Error("Fan missing fanvue_fan_id");

                    const settings = (creator.settings_json || {}) as CreatorSettings;
                    const fallbackReply = await generateMediaFallbackResponse(settings);

                    const sent = await sendFanvueMessage(fanData.fanvue_fan_id, fallbackReply, accessToken);

                    const { error: insMsgErr } = await supabase.from("messages").insert({
                        creator_id,
                        fan_id,
                        direction: "outbound",
                        text: fallbackReply,
                        provider_message_id: sent.id,
                        created_at: new Date().toISOString(),
                    });
                    throwIfSupabaseError("messages insert failed", insMsgErr);

                    const { error: upsertErr } = await supabase.from("conversation_state").upsert(
                        { creator_id, fan_id, last_bot_message_at: new Date().toISOString(), updated_at: new Date().toISOString() },
                        { onConflict: "creator_id,fan_id" },
                    );
                    throwIfSupabaseError("conversation_state upsert failed", upsertErr);

                    const { error: doneErr } = await supabase
                        .from("jobs_queue")
                        .update({ status: "completed", last_error: null })
                        .eq("id", job.id)
                        .eq("status", "processing");
                    throwIfSupabaseError("jobs_queue complete failed", doneErr);

                    completed++;
                    continue;
                }

                // Normal reply
                const history: ChatMessage[] = (messages || []).reverse().map((m: any) => ({
                    role: m.direction === "inbound" ? "user" : "assistant",
                    content: m.text,
                }));

                const fanStage = job.payload?.fan_stage || "new";
                const settings = (creator.settings_json || {}) as CreatorSettings;
                const replyContent = await generateReply(history, settings, undefined, fanStage);

                const { data: fanData, error: fanError } = await supabase
                    .from("fans")
                    .select("fanvue_fan_id")
                    .eq("id", fan_id)
                    .single();

                throwIfSupabaseError("Fan select failed", fanError);
                if (!fanData?.fanvue_fan_id) throw new Error("Fan missing fanvue_fan_id");

                const sent = await sendFanvueMessage(fanData.fanvue_fan_id, replyContent, accessToken);

                const { error: insErr } = await supabase.from("messages").insert({
                    creator_id,
                    fan_id,
                    direction: "outbound",
                    text: replyContent,
                    provider_message_id: sent.id,
                    created_at: new Date().toISOString(),
                });
                throwIfSupabaseError("messages insert failed", insErr);

                const { error: csErr } = await supabase.from("conversation_state").upsert(
                    { creator_id, fan_id, last_bot_message_at: new Date().toISOString(), updated_at: new Date().toISOString() },
                    { onConflict: "creator_id,fan_id" },
                );
                throwIfSupabaseError("conversation_state upsert failed", csErr);

                // Check for new messages during processing
                const jobLastMessageAt = job.payload?.last_message_at;
                if (jobLastMessageAt) {
                    const { data: newerMessages, error: newerErr } = await supabase
                        .from("messages")
                        .select("id")
                        .eq("creator_id", creator_id)
                        .eq("fan_id", fan_id)
                        .eq("direction", "inbound")
                        .gt("created_at", jobLastMessageAt)
                        .limit(1);

                    throwIfSupabaseError("newer messages select failed", newerErr);

                    if (newerMessages && newerMessages.length > 0) {
                        const newDelay = 30 + Math.random() * 50;
                        const { error: qErr } = await supabase.from("jobs_queue").insert({
                            creator_id,
                            fan_id,
                            job_type: "reply",
                            status: "queued",
                            run_at: new Date(Date.now() + newDelay * 1000).toISOString(),
                            payload: { fan_stage: job.payload?.fan_stage || "new", fanvue_fan_id: fanData.fanvue_fan_id },
                        });
                        throwIfSupabaseError("jobs_queue insert followup failed", qErr);
                    }
                }

            } else if (job.job_type === "followup") {
                const creator_id = job.creator_id;
                const fan_id = job.fan_id;
                if (!fan_id) throw new Error("Job is missing fan_id");

                const amount = job.payload?.amount;
                if (amount === undefined || amount === null) throw new Error("Job payload missing amount");

                const { data: creator, error: cErr } = await supabase
                    .from("creators")
                    .select("settings_json, is_active")
                    .eq("id", creator_id)
                    .single();
                throwIfSupabaseError("Creator select failed", cErr);

                if (!creator?.is_active) throw new Error("Creator is not active");

                const { token: followupAccessToken, error: tErr } = await getValidAccessToken(supabase, creator_id);
                if (tErr || !followupAccessToken) throw new Error(`No access token: ${tErr || "Token unavailable"}`);

                const { data: fanData, error: fErr } = await supabase
                    .from("fans")
                    .select("fanvue_fan_id, username")
                    .eq("id", fan_id)
                    .single();
                throwIfSupabaseError("Fan select failed", fErr);
                if (!fanData?.fanvue_fan_id) throw new Error("Fan missing fanvue_fan_id");

                const settings = (creator.settings_json || {}) as CreatorSettings;
                const thankYouMessage = await generateReply(
                    [{ role: "user", content: `[System: Fan just sent a tip of $${amount}]` }],
                    settings,
                    `Generate a flirty thank-you message for a $${amount} tip. Be grateful but playful.`,
                );

                const sent = await sendFanvueMessage(fanData.fanvue_fan_id, thankYouMessage, followupAccessToken);

                const { error: insErr } = await supabase.from("messages").insert({
                    creator_id,
                    fan_id,
                    direction: "outbound",
                    text: thankYouMessage,
                    provider_message_id: sent.id ?? `tip-${Date.now()}`,
                    created_at: new Date().toISOString(),
                });
                throwIfSupabaseError("messages insert failed", insErr);

            } else if (job.job_type === "broadcast") {
                const creator_id = job.creator_id;
                const payload = job.payload || {};

                const messageText = payload.message_text;
                const targetAudiences = payload.target_audiences || [];
                const targetAudienceTypes = payload.target_audience_types || [];
                const excludeAudiences = payload.exclude_audiences || [];
                const excludeAudienceTypes = payload.exclude_audience_types || [];

                if (!messageText) throw new Error("Broadcast job missing message_text");
                if (targetAudiences.length === 0) throw new Error("Broadcast job missing target_audiences");

                const { data: creator, error: creatorError } = await supabase
                    .from("creators")
                    .select("fanvue_creator_id, settings_json, is_active")
                    .eq("id", creator_id)
                    .single();
                throwIfSupabaseError("Creator select failed", creatorError);

                if (!creator?.is_active) throw new Error("Creator is not active");
                if (!creator.fanvue_creator_id) throw new Error("Creator missing fanvue_creator_id");

                const creatorUserUuid = String(creator.fanvue_creator_id);

                const { token: broadcastAccessToken, error: tokenErr } = await getValidAccessToken(supabase, creator_id);
                if (tokenErr || !broadcastAccessToken) {
                    throw new Error(`No access token: ${tokenErr || "Token unavailable"}`);
                }

                const smartListTypes: string[] = [];
                const customListUuids: string[] = [];
                const excludeSmartListTypes: string[] = [];
                const excludeCustomListUuids: string[] = [];

                for (let i = 0; i < targetAudiences.length; i++) {
                    const audienceId = targetAudiences[i];
                    const audienceType = targetAudienceTypes[i] || "smart";
                    if (audienceType === "custom") customListUuids.push(audienceId);
                    else smartListTypes.push(audienceId);
                }

                for (let i = 0; i < excludeAudiences.length; i++) {
                    const audienceId = excludeAudiences[i];
                    const audienceType = excludeAudienceTypes[i] || "smart";
                    if (audienceType === "custom") excludeCustomListUuids.push(audienceId);
                    else excludeSmartListTypes.push(audienceId);
                }

                const includedLists: { smartListTypes?: string[]; customListUuids?: string[] } = {};
                if (smartListTypes.length > 0) includedLists.smartListTypes = smartListTypes;
                if (customListUuids.length > 0) includedLists.customListUuids = customListUuids;

                const massMessageRequest: MassMessageRequest = {
                    text: messageText,
                    includedLists,
                };

                if (excludeSmartListTypes.length > 0 || excludeCustomListUuids.length > 0) {
                    massMessageRequest.excludedLists = {};
                    if (excludeSmartListTypes.length > 0) massMessageRequest.excludedLists.smartListTypes = excludeSmartListTypes;
                    if (excludeCustomListUuids.length > 0) massMessageRequest.excludedLists.customListUuids = excludeCustomListUuids;
                }

                const result = await sendMassMessage(broadcastAccessToken, creatorUserUuid, massMessageRequest);
                if (!result.success) throw new Error(`sendMassMessage failed: ${result.error}`);

                const { error: updErr } = await supabase
                    .from("jobs_queue")
                    .update({
                        payload: { ...payload, result: { sent: result.sent, failed: result.failed, messageId: result.messageId } },
                    })
                    .eq("id", job.id);
                throwIfSupabaseError("jobs_queue update payload result failed", updErr);

            } else {
                throw new Error(`Unknown job type: ${job.job_type}`);
            }

            // Mark completed (nur wenn noch processing)
            const { error: doneErr } = await supabase
                .from("jobs_queue")
                .update({ status: "completed", last_error: null })
                .eq("id", job.id)
                .eq("status", "processing");

            throwIfSupabaseError("jobs_queue complete failed", doneErr);

            completed++;
            console.log(`✅ Job ${job.id} completed`);
        } catch (error) {
            console.error("❌ Job Error:", error);

            // Retry-Logik
            if (currentJobId) {
                try {
                    const { data: attemptsRow, error: attErr } = await supabase
                        .from("jobs_queue")
                        .select("attempts")
                        .eq("id", currentJobId)
                        .single();

                    throwIfSupabaseError("attempts select failed", attErr);

                    const currentAttempts = attemptsRow?.attempts ?? 0;

                    const { error: updErr } = await supabase
                        .from("jobs_queue")
                        .update({
                            status: currentAttempts >= 3 ? "failed" : "queued",
                            attempts: currentAttempts + 1,
                            last_error: String(error),
                            run_at: new Date(Date.now() + 60_000).toISOString(),
                        })
                        .eq("id", currentJobId);

                    if (updErr) console.error("❌ jobs_queue retry update failed:", updErr);
                    failed++;
                } catch (e2) {
                    errors.push({ jobId: currentJobId, error: String(e2) });
                    failed++;
                }
            } else {
                errors.push({ jobId: null, error: String(error) });
                failed++;
            }
        }
    }

    return new Response(
        JSON.stringify({
            ok: true,
            processed,
            completed,
            failed,
            skipped,
            processedJobIds,
            stoppedBecause: Date.now() >= deadline ? "deadline" : "no_more_jobs_or_batch_limit",
            errors,
        }),
        { headers: { ...CORS_HEADERS, "Content-Type": "application/json" }, status: 200 },
    );
});
