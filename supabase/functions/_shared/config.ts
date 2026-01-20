/**
 * Centralized configuration for Edge Functions
 * 
 * IMPORTANT: NO per-creator Fanvue secrets here!
 * Those are stored in creator_integrations table (per-creator).
 * 
 * Only global infrastructure secrets are read from env.
 */

// ============================================
// REQUIRED: Supabase Infrastructure
// ============================================

export const SUPABASE_URL = Deno.env.get("SUPABASE_URL") || "";
export const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
export const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") || "";

// ============================================
// REQUIRED: App Configuration
// ============================================

/** Base URL for the admin dashboard app (used for OAuth redirects) */
export const APP_BASE_URL = Deno.env.get("APP_BASE_URL") || "http://localhost:3000";

// ============================================
// OPTIONAL: Fanvue OAuth Endpoints (with defaults)
// ============================================

/** Fanvue OAuth authorize endpoint */
export const FANVUE_AUTHORIZE_URL =
    Deno.env.get("FANVUE_AUTHORIZE_URL") || "https://fanvue.com/oauth/authorize";

/** Fanvue OAuth token exchange endpoint */
export const FANVUE_TOKEN_URL =
    Deno.env.get("FANVUE_TOKEN_URL") || "https://fanvue.com/oauth/token";

/** Fanvue API base URL */
export const FANVUE_API_BASE_URL =
    Deno.env.get("FANVUE_API_BASE_URL") || "https://api.fanvue.com";

// ============================================
// OPTIONAL: LLM Configuration (for jobs-worker)
// ============================================

export const LLM_API_KEY = Deno.env.get("LLM_API_KEY") || "";
export const LLM_BASE_URL = Deno.env.get("LLM_BASE_URL") || "https://api.openai.com/v1";
export const LLM_MODEL = Deno.env.get("LLM_MODEL") || "gpt-4";

// ============================================
// Validation Helper
// ============================================

export function validateRequiredConfig(): { valid: boolean; missing: string[] } {
    const missing: string[] = [];

    if (!SUPABASE_URL) missing.push("SUPABASE_URL");
    if (!SUPABASE_SERVICE_ROLE_KEY) missing.push("SUPABASE_SERVICE_ROLE_KEY");
    if (!APP_BASE_URL || APP_BASE_URL === "http://localhost:3000") {
        console.warn("⚠️ APP_BASE_URL is using default localhost - set for production");
    }

    return {
        valid: missing.length === 0,
        missing,
    };
}

// ============================================
// NOTE: Per-Creator Secrets
// ============================================
//
// The following are stored PER-CREATOR in the database:
// - fanvue_client_id       -> creator_integrations.fanvue_client_id
// - fanvue_client_secret   -> creator_integrations.fanvue_client_secret
// - fanvue_webhook_secret  -> creator_integrations.fanvue_webhook_secret
//
// Access via service role only (RLS denies client access).
// Never expose these to the client or store globally.
// 
