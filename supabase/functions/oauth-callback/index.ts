/// <reference lib="deno.ns" />
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

/**
 * oauth-callback
 * 
 * Purpose: Handle Fanvue OAuth callback, exchange code for tokens
 * Auth: Verify JWT OFF (Fanvue redirects here without JWT)
 * 
 * Input: Query params - code, state
 * Output: Redirect to APP_BASE_URL with success/error
 */

const CORS_HEADERS = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
    const url = new URL(req.url);
    const code = url.searchParams.get("code");
    const state = url.searchParams.get("state");
    const error = url.searchParams.get("error");
    const errorDescription = url.searchParams.get("error_description");

    console.log("📥 OAuth Callback received, state:", state);

    // Get environment variables (global infrastructure only)
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const appBaseUrl = Deno.env.get("APP_BASE_URL") || "http://localhost:3000";
    const fanvueTokenUrl = Deno.env.get("FANVUE_TOKEN_URL") || "https://fanvue.com/oauth/token";

    if (!supabaseUrl || !serviceRoleKey) {
        console.error("❌ Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
        return redirectToApp(appBaseUrl, "error", "Server configuration error");
    }

    // Handle errors from Fanvue
    if (error) {
        console.error("❌ OAuth Error from Fanvue:", error, errorDescription);
        return redirectToApp(appBaseUrl, "error", `${error}: ${errorDescription}`);
    }

    if (!code || !state) {
        console.error("❌ Missing code or state");
        return redirectToApp(appBaseUrl, "error", "Missing authorization code or state");
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey);

    try {
        // 1. Lookup OAuth state to get creator_id and code_verifier
        const { data: oauthState, error: stateError } = await supabase
            .from("oauth_states")
            .select("*")
            .eq("state", state)
            .single();

        if (stateError || !oauthState) {
            console.error("❌ Invalid or expired state:", stateError);
            return redirectToApp(appBaseUrl, "error", "Invalid or expired authorization state");
        }

        // Check expiration
        if (new Date(oauthState.expires_at) < new Date()) {
            await supabase.from("oauth_states").delete().eq("state", state);
            console.error("❌ State expired");
            return redirectToApp(appBaseUrl, "error", "Authorization state expired");
        }

        const creatorId = oauthState.creator_id;
        const codeVerifier = oauthState.code_verifier;
        const redirectUri = oauthState.redirect_uri;
        const scopes = oauthState.scopes;

        console.log("✅ Found OAuth state for creator:", creatorId);

        // 2. Get creator credentials from creator_integrations (stored per-creator)
        const { data: integration, error: integrationError } = await supabase
            .from("creator_integrations")
            .select("fanvue_client_id, fanvue_client_secret")
            .eq("creator_id", creatorId)
            .eq("integration_type", "fanvue")
            .single();

        if (integrationError || !integration) {
            console.error("❌ Integration not found:", integrationError);
            return redirectToApp(appBaseUrl, "error", "Creator integration not found", creatorId);
        }

        if (!integration.fanvue_client_id || !integration.fanvue_client_secret) {
            console.error("❌ Missing client credentials in integration");
            return redirectToApp(appBaseUrl, "error", "Missing Fanvue credentials", creatorId);
        }

        console.log("✅ Loaded creator credentials from DB");

        // 3. Exchange code for tokens with PKCE
        const tokenBody: Record<string, string> = {
            grant_type: "authorization_code",
            client_id: integration.fanvue_client_id,
            client_secret: integration.fanvue_client_secret,
            redirect_uri: redirectUri,
            code: code,
        };

        // Add PKCE verifier
        if (codeVerifier) {
            tokenBody.code_verifier = codeVerifier;
        }

        console.log("📤 Exchanging code for tokens at:", fanvueTokenUrl);

        // Build form body (without client credentials - those go in Basic Auth header)
        const formBody = new URLSearchParams();
        formBody.append("grant_type", "authorization_code");
        formBody.append("redirect_uri", redirectUri);
        formBody.append("code", code);
        if (codeVerifier) {
            formBody.append("code_verifier", codeVerifier);
        }

        // Fanvue requires client_secret_basic authentication (Basic Auth header)
        const basicAuth = btoa(`${integration.fanvue_client_id}:${integration.fanvue_client_secret}`);

        const tokenResp = await fetch(fanvueTokenUrl, {
            method: "POST",
            headers: {
                "Content-Type": "application/x-www-form-urlencoded",
                "Authorization": `Basic ${basicAuth}`,
            },
            body: formBody.toString(),
        });

        if (!tokenResp.ok) {
            const errorText = await tokenResp.text();
            console.error("❌ Token exchange failed:", tokenResp.status, errorText);

            // Update integration with error
            await supabase
                .from("creator_integrations")
                .update({
                    last_webhook_error: `Token exchange failed: ${errorText}`,
                    updated_at: new Date().toISOString()
                })
                .eq("creator_id", creatorId)
                .eq("integration_type", "fanvue");

            return redirectToApp(appBaseUrl, "error", `Token exchange failed: ${tokenResp.status}`, creatorId);
        }

        const tokens = await tokenResp.json();
        console.log("✅ Tokens received, expires_in:", tokens.expires_in);

        // 4. Calculate expiration
        const expiresAt = new Date(
            Date.now() + (tokens.expires_in || 3600) * 1000
        ).toISOString();

        // 5. Store tokens in creator_oauth_tokens
        const { error: tokenError } = await supabase
            .from("creator_oauth_tokens")
            .upsert({
                creator_id: creatorId,
                access_token: tokens.access_token,
                refresh_token: tokens.refresh_token,
                expires_at: expiresAt,
                token_type: tokens.token_type || "Bearer",
                scope: tokens.scope || scopes?.join(" "),
                scopes: scopes,
                updated_at: new Date().toISOString(),
            }, { onConflict: "creator_id" });

        if (tokenError) {
            console.error("❌ Token storage error:", tokenError);
            return redirectToApp(appBaseUrl, "error", "Failed to store tokens", creatorId);
        }

        console.log("✅ Tokens stored in DB");

        // 6. Update integration status
        await supabase
            .from("creator_integrations")
            .update({
                is_connected: true,
                last_webhook_error: null,
                updated_at: new Date().toISOString(),
            })
            .eq("creator_id", creatorId)
            .eq("integration_type", "fanvue");

        // 7. Clean up OAuth state
        await supabase.from("oauth_states").delete().eq("state", state);

        console.log("✅ OAuth callback completed successfully for creator:", creatorId);

        // 8. Redirect to app with success
        return redirectToApp(appBaseUrl, "success", null, creatorId);

    } catch (err) {
        console.error("❌ OAuth Callback Error:", err);
        return redirectToApp(appBaseUrl, "error", `Server error: ${err.message}`);
    }
});

function redirectToApp(
    appBaseUrl: string,
    status: "success" | "error",
    errorMessage: string | null,
    creatorId?: string
): Response {
    const redirectUrl = new URL(`${appBaseUrl}/onboarding/callback`);
    redirectUrl.searchParams.set("status", status);

    if (errorMessage) {
        redirectUrl.searchParams.set("error", errorMessage);
    }

    if (creatorId) {
        redirectUrl.searchParams.set("creatorId", creatorId);
    }

    console.log("🔀 Redirecting to:", redirectUrl.toString());

    return new Response(null, {
        status: 302,
        headers: {
            Location: redirectUrl.toString(),
        },
    });
}
