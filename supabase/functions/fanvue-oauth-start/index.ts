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
    "Access-Control-Allow-Headers":
        "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const DEFAULT_SCOPES = [
    // IMPORTANT for refresh token:
    "openid",
    "offline_access",
    "offline",

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
    "write:creator",
];

interface OAuthStartRequest {
    creatorId: string;
    fanvueClientId: string;
    fanvueClientSecret: string;
    fanvueWebhookSecret: string;
    scopes?: string[];
}

function isValidUUID(str: string): boolean {
    const uuidRegex =
        /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    return uuidRegex.test(str);
}

function randomHex(lengthBytes: number): string {
    const array = new Uint8Array(lengthBytes);
    crypto.getRandomValues(array);
    return Array.from(array, (b) => b.toString(16).padStart(2, "0")).join("");
}

async function codeChallengeS256(verifier: string): Promise<string> {
    const encoder = new TextEncoder();
    const data = encoder.encode(verifier);
    const digest = await crypto.subtle.digest("SHA-256", data);
    const base64 = btoa(String.fromCharCode(...new Uint8Array(digest)));
    return base64.replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

serve(async (req) => {
    if (req.method === "OPTIONS") return new Response("ok", { headers: CORS_HEADERS });
    if (req.method !== "POST") {
        return new Response(JSON.stringify({ error: "Method not allowed" }), {
            status: 405,
            headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
        });
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const fanvueAuthorizeUrl = Deno.env.get("FANVUE_AUTHORIZE_URL") ||
        "https://auth.fanvue.com/oauth2/auth";

    if (!supabaseUrl || !serviceRoleKey) {
        return new Response(JSON.stringify({ error: "Server configuration error" }), {
            status: 500,
            headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
        });
    }

    try {
        const body: OAuthStartRequest = await req.json();
        const { creatorId, fanvueClientId, fanvueClientSecret, fanvueWebhookSecret, scopes } =
            body;

        if (!creatorId || !fanvueClientId || !fanvueClientSecret || !fanvueWebhookSecret) {
            return new Response(JSON.stringify({
                error: "Missing required fields",
                required: ["creatorId", "fanvueClientId", "fanvueClientSecret", "fanvueWebhookSecret"],
            }), {
                status: 400,
                headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
            });
        }

        if (!isValidUUID(creatorId)) {
            return new Response(JSON.stringify({ error: "Invalid creatorId format (must be UUID)" }), {
                status: 400,
                headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
            });
        }

        const supabase = createClient(supabaseUrl, serviceRoleKey);

        const state = randomHex(32);
        const codeVerifier = randomHex(64);
        const codeChallenge = await codeChallengeS256(codeVerifier);

        const projectRef = supabaseUrl.replace("https://", "").split(".")[0];
        const redirectUri = `https://${projectRef}.supabase.co/functions/v1/oauth-callback`;

        const requestedScopes = (scopes && scopes.length > 0) ? scopes : DEFAULT_SCOPES;

        // 1) Store credentials server-side (client must not read these; enforce via RLS)
        const { error: integrationError } = await supabase
            .from("creator_integrations")
            .upsert({
                creator_id: creatorId,
                integration_type: "fanvue",
                fanvue_client_id: fanvueClientId,
                fanvue_client_secret: fanvueClientSecret,
                fanvue_webhook_secret: fanvueWebhookSecret,
                redirect_uri: redirectUri,
                scopes: requestedScopes,
                is_connected: false,
                last_webhook_error: null,
                updated_at: new Date().toISOString(),
            }, { onConflict: "creator_id,integration_type" });

        if (integrationError) {
            throw new Error(`Failed to store credentials: ${integrationError.message}`);
        }

        // 2) Store oauth state for callback
        const { error: stateError } = await supabase
            .from("oauth_states")
            .upsert({
                state,
                creator_id: creatorId,
                code_verifier: codeVerifier,
                redirect_uri: redirectUri,
                scopes: requestedScopes,
                created_at: new Date().toISOString(),
                expires_at: new Date(Date.now() + 10 * 60 * 1000).toISOString(), // 10 min
            }, { onConflict: "state" });

        if (stateError) {
            throw new Error(`Failed to store OAuth state: ${stateError.message}`);
        }

        // 3) Build authorize URL
        const authorizeUrl = new URL(fanvueAuthorizeUrl);
        authorizeUrl.searchParams.set("client_id", fanvueClientId);
        authorizeUrl.searchParams.set("redirect_uri", redirectUri);
        authorizeUrl.searchParams.set("response_type", "code");
        authorizeUrl.searchParams.set("scope", requestedScopes.join(" "));
        authorizeUrl.searchParams.set("state", state);
        authorizeUrl.searchParams.set("code_challenge", codeChallenge);
        authorizeUrl.searchParams.set("code_challenge_method", "S256");

        // IMPORTANT: Force re-consent so refresh_token is actually returned
        authorizeUrl.searchParams.set("prompt", "consent");

        return new Response(JSON.stringify({
            authorizeUrl: authorizeUrl.toString(),
            redirectUri,
            state,
        }), {
            status: 200,
            headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
        });
    } catch (e) {
        return new Response(JSON.stringify({ error: String(e) }), {
            status: 500,
            headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
        });
    }
});
