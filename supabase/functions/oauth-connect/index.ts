/// <reference lib="deno.ns" />
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { crypto } from "https://deno.land/std@0.177.0/crypto/mod.ts";

/**
 * oauth-connect - Start OAuth flow for existing creator
 * 
 * This function reads credentials from DB and starts OAuth flow.
 * Called by Admin UI "Connect OAuth" button.
 * 
 * Input: GET ?creatorId=UUID
 * Output: Redirect to Fanvue authorize URL
 */

const CORS_HEADERS = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const DEFAULT_SCOPES = [
    "read:chat",
    "write:chat",
    "read:self",
    "read:creator",
    "read:fan",
    "read:media",
    "write:media",
    "read:post",
    "write:post",
    "read:insights",
    "write:creator"
];

function generateRandomString(length: number): string {
    const array = new Uint8Array(length);
    crypto.getRandomValues(array);
    return Array.from(array, (byte) => byte.toString(16).padStart(2, "0")).join("");
}

async function generateCodeChallenge(verifier: string): Promise<string> {
    const encoder = new TextEncoder();
    const data = encoder.encode(verifier);
    const digest = await crypto.subtle.digest("SHA-256", data);
    const base64 = btoa(String.fromCharCode(...new Uint8Array(digest)));
    return base64.replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

serve(async (req) => {
    if (req.method === "OPTIONS") {
        return new Response("ok", { headers: CORS_HEADERS });
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !serviceRoleKey) {
        return new Response("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY", { status: 500 });
    }

    // Get creatorId from query params
    const url = new URL(req.url);
    const creatorId = url.searchParams.get("creatorId");

    if (!creatorId) {
        return new Response("Missing creatorId parameter", { status: 400 });
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey);

    try {
        // Fetch credentials from DB
        const { data: integration, error: integrationError } = await supabase
            .from("creator_integrations")
            .select("fanvue_client_id, fanvue_client_secret, fanvue_webhook_secret")
            .eq("creator_id", creatorId)
            .eq("integration_type", "fanvue")
            .single();

        if (integrationError || !integration) {
            console.error("❌ Integration not found:", integrationError);
            return new Response("Integration not found for creator", { status: 404 });
        }

        const fanvueClientId = integration.fanvue_client_id;
        const fanvueClientSecret = integration.fanvue_client_secret;
        const fanvueWebhookSecret = integration.fanvue_webhook_secret;

        if (!fanvueClientId) {
            return new Response("Missing FANVUE_CLIENT_ID", { status: 400 });
        }

        if (!fanvueClientSecret) {
            return new Response("Missing FANVUE_CLIENT_SECRET", { status: 400 });
        }

        // Generate PKCE
        const codeVerifier = generateRandomString(43);
        const codeChallenge = await generateCodeChallenge(codeVerifier);
        const state = generateRandomString(32);

        // Build redirect URI
        const redirectUri = `${supabaseUrl}/functions/v1/oauth-callback`;

        // Store state in DB
        const expiresAt = new Date(Date.now() + 10 * 60 * 1000).toISOString(); // 10 min

        const { error: stateError } = await supabase
            .from("oauth_states")
            .insert({
                state,
                creator_id: creatorId,
                code_verifier: codeVerifier,
                redirect_uri: redirectUri,
                scopes: DEFAULT_SCOPES,
                expires_at: expiresAt,
            });

        if (stateError) {
            console.error("❌ Failed to store state:", stateError);
            return new Response("Failed to store OAuth state", { status: 500 });
        }

        // Build authorize URL
        const authorizeUrl = new URL("https://auth.fanvue.com/oauth2/auth");
        authorizeUrl.searchParams.set("response_type", "code");
        authorizeUrl.searchParams.set("client_id", fanvueClientId);
        authorizeUrl.searchParams.set("redirect_uri", redirectUri);
        authorizeUrl.searchParams.set("scope", DEFAULT_SCOPES.join(" "));
        authorizeUrl.searchParams.set("state", state);
        authorizeUrl.searchParams.set("code_challenge", codeChallenge);
        authorizeUrl.searchParams.set("code_challenge_method", "S256");

        console.log(`✅ OAuth started for creator ${creatorId}, redirecting to Fanvue`);

        // Redirect to Fanvue
        return new Response(null, {
            status: 302,
            headers: {
                ...CORS_HEADERS,
                "Location": authorizeUrl.toString(),
            },
        });

    } catch (error) {
        console.error("❌ OAuth connect error:", error);
        return new Response(`Error: ${error}`, { status: 500 });
    }
});
