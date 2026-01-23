/**
 * Supabase Client Factory
 * 
 * Creates Supabase clients for Edge Functions.
 * Uses SUPABASE_SERVICE_ROLE_KEY for server-side operations.
 */

/**
 * Supabase Client Factory (Edge Functions)
 */

import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

function must(name: string): string {
    const v = Deno.env.get(name);
    if (!v) throw new Error(`Missing env var: ${name}`);
    return v;
}

export function createSupabaseServiceClient(): SupabaseClient {
    const supabaseUrl = must("SUPABASE_URL");
    const serviceRoleKey = must("SUPABASE_SERVICE_ROLE_KEY");

    // Debug: zeigt dir im Function-Log, welches Projekt wirklich genutzt wird
    console.log("[ENV] SUPABASE_URL =", supabaseUrl);

    return createClient(supabaseUrl, serviceRoleKey, {
        auth: { persistSession: false },
    });
}

export function createSupabaseAnonClient(): SupabaseClient {
    const supabaseUrl = must("SUPABASE_URL");
    const anonKey = must("SUPABASE_ANON_KEY");

    return createClient(supabaseUrl, anonKey, {
        auth: { persistSession: false },
    });
}

export const getSupabaseClient = createSupabaseServiceClient;
