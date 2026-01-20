/**
 * Supabase Client Factory
 * 
 * Creates Supabase clients for Edge Functions.
 * Uses SUPABASE_SERVICE_ROLE_KEY for server-side operations.
 */

import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

/**
 * Create a Supabase client with Service Role key.
 * Use this for all server-side DB operations that need to bypass RLS.
 */
export function createSupabaseServiceClient(): SupabaseClient {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !serviceRoleKey) {
        throw new Error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
    }

    return createClient(supabaseUrl, serviceRoleKey, {
        auth: { persistSession: false },
    });
}

/**
 * Create a Supabase client with Anon key.
 * Use this for operations that should respect RLS.
 */
export function createSupabaseAnonClient(): SupabaseClient {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY");

    if (!supabaseUrl || !anonKey) {
        throw new Error("Missing SUPABASE_URL or SUPABASE_ANON_KEY");
    }

    return createClient(supabaseUrl, anonKey, {
        auth: { persistSession: false },
    });
}

/**
 * Legacy function name for backward compatibility.
 * @deprecated Use createSupabaseServiceClient() instead.
 */
export const getSupabaseClient = createSupabaseServiceClient;
