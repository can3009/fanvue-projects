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

    creator_id: string;
    fan_id: string | null;

    payload: any;
};

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
            if (!fan_message) throw new Error("Job payload missing fan_message");

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

            // Conversation history
            const { data: messages, error: msgErr } = await supabase
                .from("messages")
                .select("direction, text, created_at")
                .eq("creator_id", creator_id)
                .eq("fan_id", fan_id)
                .order("created_at", { ascending: true })
                .limit(10);

            if (msgErr) throw new Error(`Messages select failed: ${msgErr.message}`);

            const history: ChatMessage[] = (messages || []).map((m: any) => ({
                role: m.direction === "inbound" ? "user" : "assistant",
                content: m.text,
            }));

            console.log(`📝 Conversation history: ${history.length} messages`);

            const settings = (creator.settings_json || {}) as CreatorSettings;
            const replyContent = await generateReply(history, settings);
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
