/// <reference lib="deno.ns" />
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
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

// Generate unique media fallback response via LLM
async function generateMediaFallbackResponse(settings: CreatorSettings): Promise<string> {
    const systemPrompt = `Du bist ein flirty Chat-Partner. Der User hat dir ein Bild/Video geschickt, aber du kannst es technisch NICHT sehen - du siehst nur ein Anhang-Symbol.

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
        systemPrompt
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

serve(async (req) => {
    if (req.method === "OPTIONS") {
        return new Response("ok", { headers: CORS_HEADERS });
    }

    const supabase = createSupabaseServiceClient();

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
            return new Response(
                JSON.stringify({ processed: false, message: "No jobs to process" }),
                { headers: { ...CORS_HEADERS, "Content-Type": "application/json" }, status: 200 },
            );
        }

        // 2) Atomisches Claiming: nur wenn Status noch "queued" ist -> "processing"
        //    Wenn ein zweiter Worker parallel läuft, wird genau einer erfolgreich claimen.
        const { data: claimed, error: claimErr } = await supabase
            .from("jobs_queue")
            .update({ status: "processing" })
            .eq("id", job.id)
            .eq("status", "queued")
            .select("id")
            .maybeSingle();

        throwIfSupabaseError("❌ Job claim error", claimErr);

        if (!claimed) {
            // Jemand anderes hat den Job schneller geclaimed -> kein Fehler, einfach sauber beenden.
            return new Response(
                JSON.stringify({ processed: false, message: "Job already claimed by another worker" }),
                { headers: { ...CORS_HEADERS, "Content-Type": "application/json" }, status: 200 },
            );
        }

        currentJobId = job.id;
        console.log(`🔄 Processing Job ${job.id} (type: ${job.job_type})`);

        // ========== REPLY JOB ==========
        if (job.job_type === "reply") {
            const creator_id = job.creator_id;
            const fan_id = job.fan_id;

            if (!fan_id) throw new Error("Job is missing fan_id (NULL). Fix jobs_queue row.");

            const fan_message = job.payload?.fan_message;
            const hasMedia = job.payload?.has_media === true;

            if (!fan_message && !hasMedia) throw new Error("Job payload missing fan_message and no media");

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

                return new Response(JSON.stringify({ processed: true, skipped: true, reason: "already_replied" }), {
                    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
                    status: 200,
                });
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
            const { token: accessToken, error: tokenError } = await getValidAccessToken(supabase, creator_id);
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
                console.log(`🎭 LLM fallback: ${fallbackReply.substring(0, 50)}...`);

                const sent = await sendFanvueMessage(fanData.fanvue_fan_id, fallbackReply, accessToken);
                console.log(`📤 Fallback sent: ${sent.id}`);

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

                console.log(`✅ Job ${job.id} completed (media fallback)`);

                return new Response(JSON.stringify({ processed: true, jobId: job.id, type: job.job_type, fallback: true }), {
                    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
                    status: 200,
                });
            }

            // Normal reply
            const history: ChatMessage[] = (messages || []).reverse().map((m: any) => ({
                role: m.direction === "inbound" ? "user" : "assistant",
                content: m.text,
            }));

            console.log(`📝 History: ${history.length} messages`);

            const fanStage = job.payload?.fan_stage || 'new';
            const settings = (creator.settings_json || {}) as CreatorSettings;
            const replyContent = await generateReply(history, settings, undefined, fanStage);
            console.log(`🤖 Generated: ${replyContent.substring(0, 80)}...`);

            const { data: fanData, error: fanError } = await supabase
                .from("fans")
                .select("fanvue_fan_id")
                .eq("id", fan_id)
                .single();

            throwIfSupabaseError("Fan select failed", fanError);
            if (!fanData?.fanvue_fan_id) throw new Error("Fan missing fanvue_fan_id");

            const sent = await sendFanvueMessage(fanData.fanvue_fan_id, replyContent, accessToken);
            console.log(`📤 Message sent: ${sent.id}`);

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
                    console.log("📨 New messages arrived - creating follow-up job");
                    const newDelay = 30 + Math.random() * 50;

                    const { error: qErr } = await supabase.from("jobs_queue").insert({
                        creator_id,
                        fan_id,
                        job_type: "reply",
                        status: "queued",
                        run_at: new Date(Date.now() + newDelay * 1000).toISOString(),
                        payload: { fan_stage: job.payload?.fan_stage || 'new', fanvue_fan_id: fanData.fanvue_fan_id },
                    });
                    throwIfSupabaseError("jobs_queue insert followup failed", qErr);
                }
            }

            // ========== FOLLOWUP JOB ==========
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

            // ========== BROADCAST JOB ==========
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

            // Nur Warnung: verhindert stilles „verschlucken“ bei mismatch
            if (targetAudienceTypes.length > 0 && targetAudienceTypes.length !== targetAudiences.length) {
                console.warn("⚠️ Broadcast: target_audience_types length != target_audiences length");
            }

            console.log(`📣 Broadcast for creator ${creator_id}`);
            console.log(`📣 Targets: ${JSON.stringify(targetAudiences)}`);
            console.log(`📣 Types: ${JSON.stringify(targetAudienceTypes)}`);

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
                const audienceType = targetAudienceTypes[i] || 'smart';

                if (audienceType === 'custom') {
                    customListUuids.push(audienceId);
                } else {
                    smartListTypes.push(audienceId);
                }
            }

            for (let i = 0; i < excludeAudiences.length; i++) {
                const audienceId = excludeAudiences[i];
                const audienceType = excludeAudienceTypes[i] || 'smart';

                if (audienceType === 'custom') {
                    excludeCustomListUuids.push(audienceId);
                } else {
                    excludeSmartListTypes.push(audienceId);
                }
            }

            console.log(`📣 Smart lists: ${smartListTypes.join(", ") || "none"}`);
            console.log(`📣 Custom lists: ${customListUuids.join(", ") || "none"}`);

            if (smartListTypes.length === 0 && customListUuids.length === 0) {
                throw new Error("Broadcast requires at least one target list");
            }

            const includedLists: { smartListTypes?: string[]; customListUuids?: string[] } = {};
            if (smartListTypes.length > 0) includedLists.smartListTypes = smartListTypes;
            if (customListUuids.length > 0) includedLists.customListUuids = customListUuids;

            const massMessageRequest: MassMessageRequest = {
                text: messageText,
                includedLists,
            };

            if (excludeSmartListTypes.length > 0 || excludeCustomListUuids.length > 0) {
                // Keys nur setzen, wenn wirklich vorhanden -> keine undefined-Felder
                massMessageRequest.excludedLists = {};
                if (excludeSmartListTypes.length > 0) massMessageRequest.excludedLists.smartListTypes = excludeSmartListTypes;
                if (excludeCustomListUuids.length > 0) massMessageRequest.excludedLists.customListUuids = excludeCustomListUuids;
            }

            const result = await sendMassMessage(broadcastAccessToken, creatorUserUuid, massMessageRequest);

            if (!result.success) {
                throw new Error(`sendMassMessage failed: ${result.error}`);
            }

            console.log(`✅ Broadcast sent: ${result.sent} sent, ${result.failed} failed`);

            const { error: updErr } = await supabase.from("jobs_queue").update({
                payload: { ...payload, result: { sent: result.sent, failed: result.failed, messageId: result.messageId } },
            }).eq("id", job.id);
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

        console.log(`✅ Job ${job.id} completed`);

        return new Response(JSON.stringify({ processed: true, jobId: job.id, type: job.job_type }), {
            headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
            status: 200,
        });

    } catch (error) {
        console.error("❌ Job Error:", error);

        if (currentJobId) {
            const { data: attemptsRow, error: attErr } = await supabase
                .from("jobs_queue")
                .select("attempts")
                .eq("id", currentJobId)
                .single();

            throwIfSupabaseError("attempts select failed", attErr);

            const currentAttempts = attemptsRow?.attempts ?? 0;

            const { error: updErr } = await supabase.from("jobs_queue").update({
                status: currentAttempts >= 3 ? "failed" : "queued",
                attempts: currentAttempts + 1,
                last_error: String(error),
                run_at: new Date(Date.now() + 60_000).toISOString(),
            }).eq("id", currentJobId);
            // Im Error-Path nur loggen (nicht nochmal crashen)
            if (updErr) console.error("❌ jobs_queue retry update failed:", updErr);
        }

        return new Response(JSON.stringify({ processed: false, error: String(error), jobId: currentJobId }), {
            headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
            status: 500,
        });
    }
});
