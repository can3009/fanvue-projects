/**
 * Token Manager
 *
 * Handles automatic OAuth token refresh for Fanvue API.
 * Tokens are refreshed when they expire or are about to expire (5 min buffer).
 */

import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const FANVUE_TOKEN_URL = "https://fanvue.com/oauth/token";
const TOKEN_EXPIRY_BUFFER_MS = 5 * 60 * 1000; // 5 minutes before expiry

export interface TokenInfo {
    access_token: string;
    refresh_token: string | null;
    expires_at: string;
}

export interface RefreshResult {
    success: boolean;
    access_token?: string;
    error?: string;
}

/**
 * Get a valid access token for a creator.
 * Automatically refreshes if expired or about to expire.
 */
export async function getValidAccessToken(
    supabase: SupabaseClient,
    creatorId: string
): Promise<{ token: string | null; error: string | null }> {
    console.log(`🔑 [TokenManager] Getting valid token for creator ${creatorId}`);

    // 1. Get current tokens from DB
    const { data: tokens, error: tokenError } = await supabase
        .from("creator_oauth_tokens")
        .select("access_token, refresh_token, expires_at")
        .eq("creator_id", creatorId)
        .single();

    if (tokenError || !tokens) {
        console.error("❌ [TokenManager] No tokens found:", tokenError);
        return { token: null, error: "No OAuth tokens found for creator" };
    }

    if (!tokens.access_token) {
        return { token: null, error: "Access token is empty" };
    }

    // 2. Check if token is still valid (with buffer)
    const expiresAt = new Date(tokens.expires_at).getTime();
    const now = Date.now();
    const isExpired = now >= (expiresAt - TOKEN_EXPIRY_BUFFER_MS);

    if (!isExpired) {
        console.log(`✅ [TokenManager] Token still valid, expires in ${Math.round((expiresAt - now) / 1000 / 60)} minutes`);
        return { token: tokens.access_token, error: null };
    }

    console.log(`⚠️ [TokenManager] Token expired or expiring soon, refreshing...`);

    // 3. Token is expired, try to refresh
    if (!tokens.refresh_token) {
        console.error("❌ [TokenManager] No refresh token available");
        return { token: null, error: "Token expired and no refresh token available. Please reconnect OAuth." };
    }

    // 4. Get client credentials from creator_integrations
    const { data: integration, error: integrationError } = await supabase
        .from("creator_integrations")
        .select("fanvue_client_id, fanvue_client_secret")
        .eq("creator_id", creatorId)
        .eq("integration_type", "fanvue")
        .single();

    if (integrationError || !integration?.fanvue_client_id || !integration?.fanvue_client_secret) {
        console.error("❌ [TokenManager] Missing client credentials:", integrationError);
        return { token: null, error: "Missing Fanvue client credentials" };
    }

    // 5. Refresh the token
    const refreshResult = await refreshAccessToken(
        tokens.refresh_token,
        integration.fanvue_client_id,
        integration.fanvue_client_secret
    );

    if (!refreshResult.success || !refreshResult.access_token) {
        console.error("❌ [TokenManager] Refresh failed:", refreshResult.error);

        // Mark integration as disconnected
        await supabase
            .from("creator_integrations")
            .update({
                is_connected: false,
                last_webhook_error: `Token refresh failed: ${refreshResult.error}`,
                updated_at: new Date().toISOString(),
            })
            .eq("creator_id", creatorId)
            .eq("integration_type", "fanvue");

        return { token: null, error: refreshResult.error || "Token refresh failed" };
    }

    // 6. Store new tokens
    const { error: updateError } = await supabase
        .from("creator_oauth_tokens")
        .update({
            access_token: refreshResult.access_token,
            refresh_token: refreshResult.refresh_token || tokens.refresh_token,
            expires_at: refreshResult.expires_at,
            updated_at: new Date().toISOString(),
        })
        .eq("creator_id", creatorId);

    if (updateError) {
        console.error("❌ [TokenManager] Failed to store refreshed token:", updateError);
        // Still return the new token, it's valid even if we failed to store it
    } else {
        console.log(`✅ [TokenManager] Token refreshed and stored, new expiry: ${refreshResult.expires_at}`);
    }

    return { token: refreshResult.access_token, error: null };
}

/**
 * Refresh an access token using the refresh token
 */
async function refreshAccessToken(
    refreshToken: string,
    clientId: string,
    clientSecret: string
): Promise<RefreshResult & { refresh_token?: string; expires_at?: string }> {
    console.log(`🔄 [TokenManager] Refreshing access token...`);

    try {
        // Build form body
        const formBody = new URLSearchParams();
        formBody.append("grant_type", "refresh_token");
        formBody.append("refresh_token", refreshToken);

        // Use Basic Auth for client credentials
        const basicAuth = btoa(`${clientId}:${clientSecret}`);

        const response = await fetch(FANVUE_TOKEN_URL, {
            method: "POST",
            headers: {
                "Content-Type": "application/x-www-form-urlencoded",
                "Authorization": `Basic ${basicAuth}`,
            },
            body: formBody.toString(),
        });

        const responseText = await response.text();
        console.log(`📥 [TokenManager] Refresh response (${response.status}): ${responseText.substring(0, 200)}`);

        if (!response.ok) {
            // Parse error if possible
            try {
                const errorJson = JSON.parse(responseText);
                return {
                    success: false,
                    error: errorJson.error_description || errorJson.error || `HTTP ${response.status}`,
                };
            } catch {
                return {
                    success: false,
                    error: `HTTP ${response.status}: ${responseText}`,
                };
            }
        }

        const tokens = JSON.parse(responseText);

        // Calculate new expiration
        const expiresAt = new Date(
            Date.now() + (tokens.expires_in || 3600) * 1000
        ).toISOString();

        return {
            success: true,
            access_token: tokens.access_token,
            refresh_token: tokens.refresh_token, // May be a new refresh token
            expires_at: expiresAt,
        };

    } catch (err) {
        console.error("❌ [TokenManager] Refresh error:", err);
        return {
            success: false,
            error: `Refresh failed: ${err instanceof Error ? err.message : String(err)}`,
        };
    }
}
