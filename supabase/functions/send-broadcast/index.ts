import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
    if (req.method === "OPTIONS") {
        return new Response("ok", { headers: corsHeaders });
    }

    try {
        const { creator_id, target_audiences, target_audience_types, exclude_audiences, exclude_audience_types, message } = await req.json();

        if (!creator_id || !message) {
            return new Response(JSON.stringify({ error: "Missing required fields" }), {
                status: 400,
                headers: { ...corsHeaders, "Content-Type": "application/json" },
            });
        }

        const supabaseUrl = Deno.env.get("SUPABASE_URL");
        const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

        if (!supabaseUrl || !serviceRoleKey) {
            return new Response(JSON.stringify({ error: "Server configuration error" }), {
                status: 500,
                headers: { ...corsHeaders, "Content-Type": "application/json" },
            });
        }

        const supabase = createClient(supabaseUrl, serviceRoleKey);

        // 1. Resolve Audience to specific Fan IDs
        // This is complex, so for MVP we just stub it and assume list handling happens in jobs-worker or here.
        // For now, let's create a single 'broadcast' job that the worker expands?
        // OR better: Create the broadcast job directly.

        const { data: job, error: jobError } = await supabase
            .from("jobs_queue")
            .insert({
                creator_id: creator_id,
                job_type: 'broadcast',
                status: 'queued',
                payload: {
                    message_text: message,
                    target_audiences,
                    target_audience_types,
                    exclude_audiences,
                    exclude_audience_types,
                    // media: [] // TODO: Add media
                }
            })
            .select()
            .single();

        if (jobError) throw jobError;

        return new Response(
            JSON.stringify({ success: true, job_id: job.id, message: "Broadcast queued" }),
            { headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );

    } catch (error) {
        return new Response(JSON.stringify({ error: error.message }), {
            status: 500,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
    }
});
