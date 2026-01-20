/// <reference lib="deno.ns" />
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { crypto } from "https://deno.land/std@0.177.0/crypto/mod.ts";

/**
 * fanvue-oauth-start
 * 
 * Purpose: Start OAuth flow for a creator
 * Auth: Requires JWT (Verify JWT ON)
 * 
 * Input: {
 *   creatorId: UUID,
 *   fanvueClientId: string,
 *   fanvueClientSecret: string,
 *   fanvueWebhookSecret: string,
 *   scopes?: string[]
 * }
 * 
 * Output: {
 *   authorizeUrl: string,
 *   redirectUri: string,
 *   state: string
 * }
 */

const CORS_HEADERS = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// Default scopes if not provided
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

interface OAuthStartRequest {
    creatorId: string;
    fanvueClientId: string;
    fanvueClientSecret: string;
    fanvueWebhookSecret: string;
    scopes?: string[];
}

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

function isValidUUID(str: string): boolean {
    const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    return uuidRegex.test(str);
}

serve(async (req) => {
    // Handle CORS preflight
    if (req.method === "OPTIONS") {
        return new Response("ok", { headers: CORS_HEADERS });
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
    const fanvueAuthorizeUrl = Deno.env.get("FANVUE_AUTHORIZE_URL") || "https://fanvue.com/oauth/authorize";

    if (!supabaseUrl || !serviceRoleKey) {
        console.error("❌ Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
        return new Response(
            JSON.stringify({ error: "Server configuration error" }),
            { status: 500, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
        );
    }

    try {
        // Parse request body
        const body: OAuthStartRequest = await req.json();
        const { creatorId, fanvueClientId, fanvueClientSecret, fanvueWebhookSecret, scopes } = body;

        // Validate required fields
        if (!creatorId || !fanvueClientId || !fanvueClientSecret || !fanvueWebhookSecret) {
            return new Response(
                JSON.stringify({
                    error: "Missing required fields",
                    required: ["creatorId", "fanvueClientId", "fanvueClientSecret", "fanvueWebhookSecret"]
                }),
                { status: 400, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
            );
        }

        // Validate creatorId is UUID
        if (!isValidUUID(creatorId)) {
            return new Response(
                JSON.stringify({ error: "Invalid creatorId format (must be UUID)" }),
                { status: 400, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
            );
        }

        console.log("📝 OAuth Start for creator:", creatorId);

        // Service role client for DB operations
        const supabase = createClient(supabaseUrl, serviceRoleKey);

        // Generate PKCE values
        const state = generateRandomString(32);
        const codeVerifier = generateRandomString(64);
        const codeChallenge = await generateCodeChallenge(codeVerifier);

        // Build redirect URI (Supabase Functions URL)
        const projectRef = supabaseUrl.replace("https://", "").split(".")[0];
        const redirectUri = `https://${projectRef}.supabase.co/functions/v1/oauth-callback`;

        // Requested scopes
        const requestedScopes = scopes && scopes.length > 0 ? scopes : DEFAULT_SCOPES;

        // 1. Ensure creator exists in creators table
        const { error: creatorUpsertError } = await supabase
            .from("creators")
            .upsert({
                id: creatorId,
                is_active: true,
                updated_at: new Date().toISOString(),
            }, { onConflict: "id" });

        if (creatorUpsertError) {
            console.error("❌ Creator upsert error:", creatorUpsertError);
            // Continue anyway - creator might already exist
        }

        // 2. Store creator Fanvue credentials in creator_integrations
        // These are stored per-creator, NOT in global secrets
        const { error: integrationError } = await supabase
            .from("creator_integrations")
            .upsert({
                creator_id: creatorId,
                integration_type: "fanvue",
                fanvue_client_id: fanvueClientId,
                fanvue_client_secret: fanvueClientSecret,  // Stored securely, RLS denies client access
                fanvue_webhook_secret: fanvueWebhookSecret, // Stored securely, RLS denies client access
                redirect_uri: redirectUri,
                scopes: requestedScopes,
                is_connected: false,
                updated_at: new Date().toISOString(),
            }, { onConflict: "creator_id,integration_type" });

        if (integrationError) {
            console.error("❌ Integration upsert error:", integrationError);
            throw new Error(`Failed to store credentials: ${integrationError.message}`);
        }

        console.log("✅ Stored creator credentials in DB");

        // 3. Store PKCE state for callback verification
        const { error: stateError } = await supabase
            .from("oauth_states")
            .upsert({
                state: state,
                creator_id: creatorId,
                code_verifier: codeVerifier,
                redirect_uri: redirectUri,
                scopes: requestedScopes,
                created_at: new Date().toISOString(),
                expires_at: new Date(Date.now() + 10 * 60 * 1000).toISOString(), // 10 min
            }, { onConflict: "state" });

        if (stateError) {
            console.error("❌ OAuth state insert error:", stateError);
            throw new Error(`Failed to store OAuth state: ${stateError.message}`);
        }

        // 4. Build Fanvue authorize URL
        const authorizeUrl = new URL(fanvueAuthorizeUrl);
        authorizeUrl.searchParams.set("client_id", fanvueClientId);
        authorizeUrl.searchParams.set("redirect_uri", redirectUri);
        authorizeUrl.searchParams.set("response_type", "code");
        authorizeUrl.searchParams.set("scope", requestedScopes.join(" "));
        authorizeUrl.searchParams.set("state", state);
        authorizeUrl.searchParams.set("code_challenge", codeChallenge);
        authorizeUrl.searchParams.set("code_challenge_method", "S256");

        console.log("✅ OAuth Start successful, state:", state);

        return new Response(
            JSON.stringify({
                authorizeUrl: authorizeUrl.toString(),
                redirectUri: redirectUri,
                state: state,
            }),
            {
                status: 200,
                headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
            }
        );

    } catch (error) {
        console.error("❌ OAuth Start Error:", error);
        return new Response(
            JSON.stringify({ error: String(error) }),
            { status: 500, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
        );
    }
});
