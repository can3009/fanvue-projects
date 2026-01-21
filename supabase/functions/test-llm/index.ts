
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders });
    }

    try {
        const apiKey = Deno.env.get("LLM_API_KEY");
        if (!apiKey) throw new Error("Missing LLM_API_KEY in environment");

        const baseUrl = Deno.env.get("LLM_BASE_URL") || "https://api.x.ai/v1";
        const model = Deno.env.get("LLM_MODEL") || "grok-2-latest";

        console.log(`Testing LLM with URL: ${baseUrl}, Model: ${model}`);

        const resp = await fetch(`${baseUrl}/chat/completions`, {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
                "Authorization": `Bearer ${apiKey}`
            },
            body: JSON.stringify({
                model: model,
                messages: [{ role: "user", content: "Hello, are you working?" }],
                max_tokens: 10
            })
        });

        const status = resp.status;
        const text = await resp.text();

        return new Response(JSON.stringify({
            success: resp.ok,
            status,
            responseBody: text,
            config: { baseUrl, model, hasKey: !!apiKey }
        }), {
            headers: { ...corsHeaders, "Content-Type": "application/json" },
            status: 200,
        });

    } catch (error) {
        return new Response(JSON.stringify({ error: error.message }), {
            headers: { ...corsHeaders, "Content-Type": "application/json" },
            status: 200, // Return 200 to see the error body easily
        });
    }
});
