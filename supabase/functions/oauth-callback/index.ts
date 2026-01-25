/// <reference lib="deno.ns" />
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

serve(async (req) => {
    const url = new URL(req.url);
    const code = url.searchParams.get("code");
    const state = url.searchParams.get("state");
    const error = url.searchParams.get("error");
    const errorDescription = url.searchParams.get("error_description");

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const appBaseUrl = Deno.env.get("APP_BASE_URL") || "http://localhost:3000";
    const fanvueTokenUrl = Deno.env.get("FANVUE_TOKEN_URL") || "https://auth.fanvue.com/oauth2/token";

    if (!supabaseUrl || !serviceRoleKey) {
        return htmlResult(false, "Server configuration error", undefined);
    }

    if (error) {
        return htmlResult(false, `${error}: ${errorDescription ?? ""}`, undefined);
    }

    if (!code || !state) {
        return htmlResult(false, "Missing authorization code or state", undefined);
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey);

    try {
        // 1) Lookup oauth state
        const { data: oauthState, error: stateError } = await supabase
            .from("oauth_states")
            .select("*")
            .eq("state", state)
            .single();

        if (stateError || !oauthState) {
            return htmlResult(false, "Invalid or expired authorization state", undefined);
        }

        if (new Date(oauthState.expires_at) < new Date()) {
            await supabase.from("oauth_states").delete().eq("state", state);
            return htmlResult(false, "Authorization state expired", undefined);
        }

        const creatorId = oauthState.creator_id;
        const codeVerifier = oauthState.code_verifier;
        const redirectUri = oauthState.redirect_uri;
        const scopes = oauthState.scopes;

        // 2) Load integration creds
        const { data: integration, error: integrationError } = await supabase
            .from("creator_integrations")
            .select("fanvue_client_id, fanvue_client_secret")
            .eq("creator_id", creatorId)
            .eq("integration_type", "fanvue")
            .single();

        if (integrationError || !integration?.fanvue_client_id || !integration?.fanvue_client_secret) {
            return htmlResult(false, "Creator integration not found or incomplete", creatorId);
        }

        // 3) Exchange code -> tokens (PKCE)
        const formBody = new URLSearchParams();
        formBody.append("grant_type", "authorization_code");
        formBody.append("redirect_uri", redirectUri);
        formBody.append("code", code);
        if (codeVerifier) formBody.append("code_verifier", codeVerifier);

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
            await supabase
                .from("creator_integrations")
                .update({
                    last_webhook_error: `Token exchange failed: ${errorText}`,
                    is_connected: false,
                    updated_at: new Date().toISOString(),
                })
                .eq("creator_id", creatorId)
                .eq("integration_type", "fanvue");

            return htmlResult(false, `Token exchange failed: ${tokenResp.status}`, creatorId);
        }

        const tokens = await tokenResp.json();

        const expiresAt = new Date(Date.now() + (tokens.expires_in || 3600) * 1000).toISOString();
        const hasRefresh = !!tokens.refresh_token;

        // 4) Store tokens
        const { error: tokenError } = await supabase
            .from("creator_oauth_tokens")
            .upsert({
                creator_id: creatorId,
                access_token: tokens.access_token,
                refresh_token: tokens.refresh_token ?? null,
                expires_at: expiresAt,
                token_type: tokens.token_type || "Bearer",
                scope: tokens.scope || (Array.isArray(scopes) ? scopes.join(" ") : null),
                scopes: scopes,
                updated_at: new Date().toISOString(),
            }, { onConflict: "creator_id" });

        if (tokenError) {
            await supabase
                .from("creator_integrations")
                .update({
                    last_webhook_error: `Token storage error: ${tokenError.message}`,
                    is_connected: false,
                    updated_at: new Date().toISOString(),
                })
                .eq("creator_id", creatorId)
                .eq("integration_type", "fanvue");

            return htmlResult(false, "Failed to store tokens", creatorId);
        }

        // 5) Update integration status based on refresh-token presence
        await supabase
            .from("creator_integrations")
            .update({
                is_connected: hasRefresh,
                last_webhook_error: hasRefresh
                    ? null
                    : "No refresh_token returned. Reconnect with prompt=consent + offline_access.",
                updated_at: new Date().toISOString(),
            })
            .eq("creator_id", creatorId)
            .eq("integration_type", "fanvue");

        // 6) Cleanup oauth state
        await supabase.from("oauth_states").delete().eq("state", state);

        // Optional: redirect back to app base url could be implemented by you
        // For now return success html (even if no refresh, we show warning)
        return htmlResult(
            hasRefresh,
            hasRefresh ? null : "Connected but NO refresh token. Please reconnect.",
            creatorId,
        );
    } catch (err) {
        const msg = err instanceof Error ? err.message : String(err);
        return htmlResult(false, `Server error: ${msg}`, undefined);
    }
});

function htmlResult(success: boolean, errorMessage: string | null, creatorId?: string): Response {
    const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>OAuth ${success ? "Success" : "Error"}</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%);
      min-height: 100vh; display: flex; justify-content: center; align-items: center;
      color: white;
    }
    .card {
      background: rgba(255,255,255,0.1);
      backdrop-filter: blur(10px);
      border-radius: 20px;
      padding: 40px;
      text-align: center;
      max-width: 480px;
      width: calc(100% - 32px);
    }
    .icon { font-size: 64px; margin-bottom: 20px; }
    h1 { font-size: 24px; margin-bottom: 10px; }
    p { color: rgba(255,255,255,0.75); margin-bottom: 14px; }
    .success { color: #00ff88; }
    .error { color: #ff6b6b; }
    .info {
      background: rgba(255,255,255,0.1);
      padding: 10px 20px;
      border-radius: 10px;
      font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Courier New", monospace;
      font-size: 12px; word-break: break-all; margin-top: 8px;
    }
    .close-hint {
      margin-top: 18px; font-size: 14px; color: rgba(255,255,255,0.5);
    }
  </style>
</head>
<body>
  <div class="card">
    <div class="icon">${success ? "✅" : "❌"}</div>
    <h1 class="${success ? "success" : "error"}">${success ? "OAuth Connected!" : "OAuth Failed"}</h1>
    <p>${success ? "You can close this window and return to the app." : (errorMessage || "Unknown error")}</p>
    ${(!success && errorMessage) ? `<div class="info">${escapeHtml(errorMessage)}</div>` : ""}
    ${creatorId ? `<div class="info">Creator ID: ${escapeHtml(creatorId)}</div>` : ""}
    <p class="close-hint">You can close this window now.</p>
  </div>
</body>
</html>`;

    return new Response(html, {
        status: 200,
        headers: { "Content-Type": "text/html; charset=utf-8" },
    });
}

function escapeHtml(str: string): string {
    return str.replaceAll("&", "&amp;")
        .replaceAll("<", "&lt;")
        .replaceAll(">", "&gt;")
        .replaceAll('"', "&quot;")
        .replaceAll("'", "&#039;");
}
