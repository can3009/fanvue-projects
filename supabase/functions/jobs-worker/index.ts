/// <reference lib="deno.ns" />
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createSupabaseServiceClient } from "../_shared/supabaseClient.ts";
import { generateReply, ChatMessage } from "../_shared/llmClient.ts";
import { sendFanvueMessage } from "../_shared/fanvueClient.ts";
import { CreatorSettings, CORS_HEADERS } from "../_shared/types.ts";

type JobRow = {
    id: string;
    job_type: "reply" | "followup" | string;
    status: "queued" | "processing" | "completed" | "failed" | string;
    run_at: string;
    attempts: number | null;
    last_error: string | null;
    created_at: string;

    creator_id: string;
    fan_id: string | null;

    payload: any;
};

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
    // Also check for the system hint pattern
    if (trimmed.match(/^\[System:.*media.*\]$/i)) return true;
    return false;
}

serve(async (req) => {
    if (req.method === "OPTIONS") {
        return new Response("ok", { headers: CORS_HEADERS });
    }

    const supabase = createSupabaseServiceClient();
    let currentJobId: string | null = null;

    try {
        // 1) DEBUG
        const nowIso = new Date().toISOString();
        console.log("DEBUG has SUPABASE_SERVICE_ROLE_KEY:", Boolean(Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")));
        console.log("DEBUG now:", nowIso);

        const { data: sample, error: sampleErr } = await supabase
            .from("jobs_queue")
            .select("id,status,run_at,job_type,created_at,fan_id,creator_id")
            .order("created_at", { ascending: false })
            .limit(5);

        if (sampleErr) {
            console.error("DEBUG sample select error:", sampleErr);
            return new Response(JSON.stringify({ error: sampleErr.message }), {
                headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
                status: 500,
            });
        }

        // 2) Fetch next due job
        const { data: job, error: fetchError } = await supabase
            .from("jobs_queue")
            .select("*")
            .eq("status", "queued")
            .lte("run_at", nowIso)
            .order("run_at", { ascending: true })
            .limit(1)
            .maybeSingle<JobRow>();

        if (fetchError) {
            console.error("❌ Job fetch error:", fetchError);
            return new Response(JSON.stringify({ error: fetchError.message }), {
                headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
                status: 500,
            });
        }

        if (!job) {
            console.log("ℹ️ No jobs to process");
            return new Response(
                JSON.stringify({
                    message: "No jobs to process",
                    debug: {
                        hasServiceRoleKey: Boolean(Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")),
                        now: nowIso,
                        sample,
                    },
                }),
                { headers: { ...CORS_HEADERS, "Content-Type": "application/json" }, status: 200 },
            );
        }

        currentJobId = job.id;
        console.log(`🔄 Processing Job ${job.id} (type: ${job.job_type})`);

        // Mark as processing
        await supabase.from("jobs_queue").update({ status: "processing" }).eq("id", job.id);

        // 3) Process
        if (job.job_type === "reply") {
            const creator_id = job.creator_id;
            const fan_id = job.fan_id;

            // fan_id MUSS gesetzt sein, sonst können wir keine Conversation/Fanvue-ID finden
            if (!fan_id) throw new Error("Job is missing fan_id (NULL). Fix jobs_queue row.");

            const fan_message = job.payload?.fan_message;
            const message_id = job.payload?.message_id;
            const hasMedia = job.payload?.has_media === true;

            // Allow empty fan_message if has_media is true
            if (!fan_message && !hasMedia) throw new Error("Job payload missing fan_message and no media");

            // CHECK: Have we already replied to this message?
            // Look for any outbound message to this fan after the job was created
            const { data: recentOutbound } = await supabase
                .from("messages")
                .select("id, created_at")
                .eq("creator_id", creator_id)
                .eq("fan_id", fan_id)
                .eq("direction", "outbound")
                .gte("created_at", job.created_at)
                .limit(1)
                .maybeSingle();

            if (recentOutbound) {
                console.log("⏭️ Already replied to this conversation, skipping to prevent duplicate");
                // Mark as completed to avoid re-processing
                await supabase.from("jobs_queue").update({ status: "completed", last_error: "skipped:duplicate" }).eq("id", job.id);
                return new Response(JSON.stringify({ success: true, skipped: true, reason: "already_replied" }), {
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

            if (creatorError || !creator) throw new Error(`Creator not found: ${creatorError?.message}`);
            if (!creator.is_active) throw new Error("Creator is not active");

            // OAuth token
            const { data: tokens, error: tokenError } = await supabase
                .from("creator_oauth_tokens")
                .select("access_token")
                .eq("creator_id", creator_id)
                .single();

            if (tokenError || !tokens?.access_token) {
                throw new Error(`No access token found for creator: ${tokenError?.message}`);
            }

            // Conversation history - Fetch LATEST 10 messages (including has_media)
            const { data: messages, error: msgErr } = await supabase
                .from("messages")
                .select("direction, text, created_at, has_media")
                .eq("creator_id", creator_id)
                .eq("fan_id", fan_id)
                .order("created_at", { ascending: false }) // Get NEWEST first
                .limit(10);

            if (msgErr) throw new Error(`Messages select failed: ${msgErr.message}`);

            // Check the LAST inbound message for media-only fallback
            const lastInbound = (messages || []).find((m: any) => m.direction === "inbound");

            // FALLBACK LOGIC: Media received but no usable text/URL
            // Conditions: has_media=true AND (text is empty OR text is placeholder)
            if (lastInbound?.has_media === true && isMediaOnlyMessage(lastInbound.text)) {
                console.log("📎 Media-only message detected, generating unique LLM response");

                // Get Fanvue fan ID
                const { data: fanData, error: fanError } = await supabase
                    .from("fans")
                    .select("fanvue_fan_id")
                    .eq("id", fan_id)
                    .single();

                if (fanError || !fanData?.fanvue_fan_id) throw new Error(`Fan not found: ${fanError?.message}`);

                // Generate unique fallback via LLM (uses creator settings for persona)
                const settings = (creator.settings_json || {}) as CreatorSettings;
                const fallbackReply = await generateMediaFallbackResponse(settings);
                console.log(`🎭 LLM fallback reply: ${fallbackReply.substring(0, 50)}...`);

                // Send fallback to Fanvue
                const sent = await sendFanvueMessage(fanData.fanvue_fan_id, fallbackReply, tokens.access_token);
                console.log(`📤 Fallback sent to Fanvue: ${sent.id}`);

                // Store outbound
                await supabase.from("messages").insert({
                    creator_id,
                    fan_id,
                    direction: "outbound",
                    text: fallbackReply,
                    provider_message_id: sent.id,
                    created_at: new Date().toISOString(),
                });

                // Update conversation_state
                await supabase.from("conversation_state").upsert(
                    {
                        creator_id,
                        fan_id,
                        last_bot_message_at: new Date().toISOString(),
                        updated_at: new Date().toISOString(),
                    },
                    { onConflict: "creator_id,fan_id" },
                );

                // Mark job completed and return early
                await supabase.from("jobs_queue").update({ status: "completed", last_error: null }).eq("id", job.id);
                console.log(`✅ Job ${job.id} completed (media fallback)`);

                return new Response(JSON.stringify({ success: true, jobId: job.id, jobType: job.job_type, fallback: true }), {
                    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
                    status: 200,
                });
            }

            // Reverse to get chronological order (oldest to newest)
            const history: ChatMessage[] = (messages || []).reverse().map((m: any) => ({
                role: m.direction === "inbound" ? "user" : "assistant",
                content: m.text,
            }));

            console.log(`📝 Conversation history: ${history.length} messages`);

            // Get fan stage from payload (set by webhook)
            const fanStage = job.payload?.fan_stage || 'new';
            console.log(`🎭 Fan stage: ${fanStage}`);

            const settings = (creator.settings_json || {}) as CreatorSettings;
            const replyContent = await generateReply(history, settings, undefined, fanStage);
            console.log(`🤖 Generated reply: ${replyContent.substring(0, 80)}...`);

            // Fanvue fan id
            const { data: fanData, error: fanError } = await supabase
                .from("fans")
                .select("fanvue_fan_id")
                .eq("id", fan_id)
                .single();

            if (fanError || !fanData?.fanvue_fan_id) throw new Error(`Fan not found: ${fanError?.message}`);

            // Send to Fanvue (WICHTIG: sendFanvueMessage MUSS bei 401/4xx/5xx throwen, sonst wird Job completed)
            const sent = await sendFanvueMessage(fanData.fanvue_fan_id, replyContent, tokens.access_token);
            console.log(`📤 Message sent to Fanvue: ${sent.id}`);

            // Store outbound
            await supabase.from("messages").insert({
                creator_id,
                fan_id,
                direction: "outbound",
                text: replyContent,
                provider_message_id: sent.id,
                created_at: new Date().toISOString(),
            });

            // Update conversation_state
            await supabase.from("conversation_state").upsert(
                {
                    creator_id,
                    fan_id,
                    last_bot_message_at: new Date().toISOString(),
                    updated_at: new Date().toISOString(),
                },
                { onConflict: "creator_id,fan_id" },
            );

            // === CHECK: Did new messages arrive during processing? ===
            // If last_message_at on the job is newer than when we started, create a new job
            const jobLastMessageAt = job.payload?.last_message_at || job.last_message_at;
            if (jobLastMessageAt) {
                const { data: newerMessages } = await supabase
                    .from("messages")
                    .select("id")
                    .eq("creator_id", creator_id)
                    .eq("fan_id", fan_id)
                    .eq("direction", "inbound")
                    .gt("created_at", jobLastMessageAt)
                    .limit(1);

                if (newerMessages && newerMessages.length > 0) {
                    console.log("📨 New messages arrived during processing - creating follow-up job");
                    // Create a new queued job for the new messages
                    const newDelay = 30 + Math.random() * 50; // 30-80 seconds
                    await supabase.from("jobs_queue").insert({
                        creator_id,
                        fan_id,
                        job_type: "reply",
                        status: "queued",
                        run_at: new Date(Date.now() + newDelay * 1000).toISOString(),
                        last_message_at: new Date().toISOString(),
                        pending_count: 0,
                        payload: {
                            fan_stage: job.payload?.fan_stage || 'new',
                            fanvue_fan_id: fanData.fanvue_fan_id,
                        },
                    });
                }
            }
        } else if (job.job_type === "followup") {
            const creator_id = job.creator_id;
            const fan_id = job.fan_id;
            if (!fan_id) throw new Error("Job is missing fan_id (NULL). Fix jobs_queue row.");

            const amount = job.payload?.amount;
            if (amount === undefined || amount === null) throw new Error("Job payload missing amount");

            const { data: creator, error: cErr } = await supabase
                .from("creators")
                .select("settings_json, is_active")
                .eq("id", creator_id)
                .single();
            if (cErr || !creator) throw new Error(`Creator not found: ${cErr?.message}`);
            if (!creator.is_active) throw new Error("Creator is not active");

            const { data: tokens, error: tErr } = await supabase
                .from("creator_oauth_tokens")
                .select("access_token")
                .eq("creator_id", creator_id)
                .single();
            if (tErr || !tokens?.access_token) throw new Error(`No access token found: ${tErr?.message}`);

            const { data: fanData, error: fErr } = await supabase
                .from("fans")
                .select("fanvue_fan_id, username")
                .eq("id", fan_id)
                .single();
            if (fErr || !fanData?.fanvue_fan_id) throw new Error(`Fan not found: ${fErr?.message}`);

            const settings = (creator.settings_json || {}) as CreatorSettings;
            const thankYouMessage = await generateReply(
                [{ role: "user", content: `[System: Fan just sent a tip of $${amount}]` }],
                settings,
                `Generate a flirty thank-you message for a $${amount} tip. Be grateful but playful.`,
            );

            const sent = await sendFanvueMessage(fanData.fanvue_fan_id, thankYouMessage, tokens.access_token);

            await supabase.from("messages").insert({
                creator_id,
                fan_id,
                direction: "outbound",
                text: thankYouMessage,
                provider_message_id: sent.id ?? `tip-${Date.now()}`,
                created_at: new Date().toISOString(),
            });
        } else {
            throw new Error(`Unknown job_type: ${job.job_type}`);
        }

        // 4) Completed
        await supabase.from("jobs_queue").update({ status: "completed", last_error: null }).eq("id", job.id);
        console.log(`✅ Job ${job.id} completed successfully`);

        return new Response(JSON.stringify({ success: true, jobId: job.id, jobType: job.job_type }), {
            headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
            status: 200,
        });
    } catch (error) {
        console.error("❌ Job Processing Error:", error);

        if (currentJobId) {
            const attemptsRes = await supabase
                .from("jobs_queue")
                .select("attempts")
                .eq("id", currentJobId)
                .single();

            const currentAttempts = attemptsRes.data?.attempts ?? 0;

            await supabase.from("jobs_queue").update({
                status: currentAttempts >= 3 ? "failed" : "queued",
                attempts: currentAttempts + 1,
                last_error: String(error),
                run_at: new Date(Date.now() + 60_000).toISOString(),
            }).eq("id", currentJobId);
        }

        return new Response(JSON.stringify({ error: String(error), jobId: currentJobId }), {
            headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
            status: 500,
        });
    }
});
