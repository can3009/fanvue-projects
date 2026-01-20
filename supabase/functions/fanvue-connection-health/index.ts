/// <reference lib="deno.ns" />
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

/**
 * fanvue-connection-health
 * 
 * Purpose: Check OAuth token and webhook health for a creator
 * Auth: Verify JWT ON (authenticated users only)
 * 
 * Input: Query param creatorId OR uses auth.uid()
 * Output: Health status object
 */

const CORS_HEADERS = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "GET, OPTIONS",
};

interface HealthResponse {
    creatorId: string;
    connected: boolean;
    tokenPresent: boolean;
    tokenExpired: boolean;
    expiresAt: string | null;
    lastWebhookAt: string | null;
    lastWebhookError: string | null;
    integrationExists: boolean;
    scopes: string[];
}

function isValidUUID(str: string): boolean {
    const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    return uuidRegex.test(str);
}

serve(async (req) => {
    // Handle CORS preflight
    if (req.method === "OPTIONS") {
        return new Response("ok", { headers: CORS_HEADERS });
    }

    if (req.method !== "GET") {
        return new Response(
            JSON.stringify({ error: "Method not allowed" }),
            { status: 405, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
        );
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !serviceRoleKey) {
        return new Response(
            JSON.stringify({ error: "Server configuration error" }),
            { status: 500, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
        );
    }

    try {
        // Get creatorId from query param or auth
        const url = new URL(req.url);
        let creatorId = url.searchParams.get("creatorId");

        // If no creatorId in query, try to get from auth
        if (!creatorId) {
            const authHeader = req.headers.get("Authorization");
            if (authHeader) {
                const supabaseAuth = createClient(supabaseUrl, serviceRoleKey);
                const token = authHeader.replace("Bearer ", "");
                const { data: { user } } = await supabaseAuth.auth.getUser(token);
                if (user) {
                    creatorId = user.id;
                }
            }
        }

        if (!creatorId || !isValidUUID(creatorId)) {
            return new Response(
                JSON.stringify({ error: "Missing or invalid creatorId" }),
                { status: 400, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
            );
        }

        console.log("🔍 Checking health for creator:", creatorId);

        const supabase = createClient(supabaseUrl, serviceRoleKey);

        // 1. Get integration record
        const { data: integration } = await supabase
            .from("creator_integrations")
            .select("*")
            .eq("creator_id", creatorId)
            .eq("integration_type", "fanvue")
            .single();

        // 2. Get OAuth tokens
        const { data: tokens } = await supabase
            .from("creator_oauth_tokens")
            .select("expires_at, scopes, updated_at")
            .eq("creator_id", creatorId)
            .single();

        // 3. Build response
        const now = new Date();
        const tokenExpiresAt = tokens?.expires_at ? new Date(tokens.expires_at) : null;
        const tokenExpired = tokenExpiresAt ? tokenExpiresAt < now : true;

        const response: HealthResponse = {
            creatorId: creatorId,
            connected: integration?.is_connected || false,
            tokenPresent: !!tokens,
            tokenExpired: tokenExpired,
            expiresAt: tokens?.expires_at || null,
            lastWebhookAt: integration?.last_webhook_at || null,
            lastWebhookError: integration?.last_webhook_error || null,
            integrationExists: !!integration,
            scopes: tokens?.scopes || integration?.scopes || [],
        };

        console.log("✅ Health check:", response.connected ? "CONNECTED" : "NOT CONNECTED");

        return new Response(
            JSON.stringify(response),
            { status: 200, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
        );

    } catch (error) {
        console.error("❌ Health Check Error:", error);
        return new Response(
            JSON.stringify({ error: String(error) }),
            { status: 500, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
        );
    }
});
