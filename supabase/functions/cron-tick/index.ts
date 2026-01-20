/// <reference lib="deno.ns" />
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createSupabaseServiceClient } from "../_shared/supabaseClient.ts";
import { CORS_HEADERS } from "../_shared/types.ts";

/**
 * cron-tick
 * 
 * Purpose: Scheduled maintenance tasks
 * Auth: Verify JWT OFF (called by scheduler)
 * 
 * Tasks:
 * 1. Cleanup expired oauth_states
 * 2. Check for tokens needing refresh
 * 3. Trigger jobs-worker
 */

serve(async (req) => {
    if (req.method === "OPTIONS") {
        return new Response("ok", { headers: CORS_HEADERS });
    }

    const supabase = createSupabaseServiceClient();

    try {
        console.log("⏰ Cron Tick Started");
        const results: Record<string, unknown> = {};

        // 1. Cleanup expired OAuth states
        const { count: expiredStatesCount } = await supabase
            .from("oauth_states")
            .delete()
            .lt("expires_at", new Date().toISOString())
            .select("*", { count: "exact", head: true });

        results.expiredStatesCleanedUp = expiredStatesCount || 0;
        if (expiredStatesCount && expiredStatesCount > 0) {
            console.log(`🗑️ Cleaned up ${expiredStatesCount} expired OAuth states`);
        }

        // 2. Check tokens expiring soon (within 5 mins)
        const { data: expiringTokens } = await supabase
            .from("creator_oauth_tokens")
            .select("creator_id, expires_at")
            .lt("expires_at", new Date(Date.now() + 5 * 60 * 1000).toISOString())
            .gt("expires_at", new Date().toISOString());

        results.tokensExpiringSoon = expiringTokens?.length || 0;
        if (expiringTokens && expiringTokens.length > 0) {
            console.log(`⚠️ ${expiringTokens.length} tokens expiring soon - refresh needed`);
            // TODO: Implement token refresh logic
            // For each token:
            // 1. Get refresh_token from creator_oauth_tokens
            // 2. Get client_id/secret from creator_integrations
            // 3. Call FANVUE_TOKEN_URL with grant_type=refresh_token
            // 4. Update creator_oauth_tokens
        }

        // 3. Count pending jobs
        const { count: pendingJobs } = await supabase
            .from("jobs_queue")
            .select("*", { count: "exact", head: true })
            .eq("status", "queued")
            .lte("run_at", new Date().toISOString());

        results.pendingJobs = pendingJobs || 0;

        // 4. Trigger jobs-worker if there are pending jobs
        if (pendingJobs && pendingJobs > 0) {
            console.log(`📋 ${pendingJobs} pending jobs - triggering worker`);

            const supabaseUrl = Deno.env.get("SUPABASE_URL") || "";
            const projectRef = supabaseUrl.replace("https://", "").split(".")[0];
            const workerUrl = `https://${projectRef}.supabase.co/functions/v1/jobs-worker`;

            try {
                const workerResp = await fetch(workerUrl, {
                    method: "POST",
                    headers: {
                        "Content-Type": "application/json",
                        // Use service role key for internal call
                        "Authorization": `Bearer ${Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")}`,
                    },
                });
                results.workerTriggered = workerResp.ok;
                results.workerStatus = workerResp.status;
            } catch (e) {
                console.error("❌ Failed to trigger worker:", e);
                results.workerTriggered = false;
                results.workerError = String(e);
            }
        }

        console.log("✅ Cron Tick Completed", results);

        return new Response(
            JSON.stringify({ success: true, ...results }),
            { headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
        );
    } catch (error) {
        console.error("❌ Cron Tick Error:", error);
        return new Response(
            JSON.stringify({ error: String(error) }),
            { status: 500, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
        );
    }
});
