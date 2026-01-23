/// <reference lib="deno.ns" />
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createSupabaseServiceClient } from "../_shared/supabaseClient.ts";
import {
    getCustomListsRest,
    getSmartListsRest,
    KNOWN_SMART_LISTS,
} from "../_shared/fanvueRestClient.ts";
import { CORS_HEADERS } from "../_shared/types.ts";

interface AudienceList {
    id: string; // smart: type, custom: uuid
    name: string;
    fanCount: number; // smart: count, custom: membersCount
    type: "smart" | "custom";
}

serve(async (req) => {
    if (req.method === "OPTIONS") {
        return new Response("ok", { headers: CORS_HEADERS });
    }

    // 0) Body sicher parsen
    let body: any = null;
    try {
        body = await req.json();
    } catch (_e) {
        return new Response(
            JSON.stringify({
                error:
                    "Invalid JSON body. Send JSON like {\"creator_id\":\"...\"}.",
            }),
            {
                status: 400,
                headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
            },
        );
    }

    const creator_id = body?.creator_id as string | undefined;
    if (!creator_id) {
        return new Response(JSON.stringify({ error: "Missing creator_id" }), {
            status: 400,
            headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
        });
    }

    const supabase = createSupabaseServiceClient();

    console.log("=== get-fanvue-lists DBG ===");
    console.log(`creator_id: ${creator_id}`);

    // 1) Creator laden (mit maybeSingle + vollem Debug)
    const { data: creator, error: creatorError } = await supabase
        .from("creators")
        .select("id, fanvue_creator_id")
        .eq("id", creator_id)
        .maybeSingle();

    console.log(
        `creatorError: ${creatorError ? JSON.stringify(creatorError) : "null"}`,
    );
    console.log(`creatorRow: ${creator ? JSON.stringify(creator) : "null"}`);

    if (creatorError) {
        return new Response(
            JSON.stringify({
                error: "DBG: DB error while selecting creator",
                creator_id,
                creatorError,
            }),
            {
                status: 500,
                headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
            },
        );
    }

    if (!creator) {
        return new Response(
            JSON.stringify({
                error: "DBG: Creator NOT found in creators table for this id",
                creator_id,
            }),
            {
                status: 404,
                headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
            },
        );
    }

    if (!creator.fanvue_creator_id) {
        return new Response(
            JSON.stringify({
                error: "DBG: Creator found but fanvue_creator_id is NULL/empty",
                creator_id,
                creator,
            }),
            {
                status: 404,
                headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
            },
        );
    }

    // 2) Token laden (Debug)
    const { data: tokens, error: tokenError } = await supabase
        .from("creator_oauth_tokens")
        .select("access_token")
        .eq("creator_id", creator_id)
        .maybeSingle();

    console.log(
        `tokenError: ${tokenError ? JSON.stringify(tokenError) : "null"}`,
    );
    console.log(`hasToken: ${tokens?.access_token ? "yes" : "no"}`);

    if (tokenError) {
        return new Response(
            JSON.stringify({
                error: "DBG: DB error while selecting token",
                creator_id,
                tokenError,
            }),
            {
                status: 500,
                headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
            },
        );
    }

    if (!tokens?.access_token) {
        return new Response(
            JSON.stringify({
                error: "DBG: No access token found in creator_oauth_tokens",
                creator_id,
            }),
            {
                status: 401,
                headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
            },
        );
    }

    const creatorUserUuid = String(creator.fanvue_creator_id);
    const accessToken = String(tokens.access_token);

    console.log(`fanvue_creator_id: ${creatorUserUuid}`);

    // 3) Custom lists
    let customListsRaw: any[] = [];
    try {
        customListsRaw = await getCustomListsRest(accessToken, creatorUserUuid);
        console.log(`customListsRaw.length=${customListsRaw.length}`);
    } catch (err) {
        console.error("custom lists fetch failed:", err);
    }

    // 4) Smart lists
    let smartListsRaw: any[] = [];
    try {
        smartListsRaw = await getSmartListsRest(accessToken, creatorUserUuid);
        console.log(`smartListsRaw.length=${smartListsRaw.length}`);
    } catch (_err) {
        console.warn("smart lists api not available, fallback");
    }

    if (smartListsRaw.length === 0) smartListsRaw = KNOWN_SMART_LISTS;

    // Map smart lists - count von API übernehmen
    const smartLists: AudienceList[] = smartListsRaw.map((sl: any) => ({
        id: String(sl.type),
        name: String(sl.name),
        fanCount: Number(sl.count ?? 0),
        type: "smart",
    }));

    // Map custom lists - membersCount von API übernehmen
    const customLists: AudienceList[] = customListsRaw.map((cl: any) => ({
        id: String(cl.uuid),
        name: String(cl.name),
        fanCount: Number(cl.membersCount ?? 0),
        type: "custom",
    }));

    return new Response(
        JSON.stringify({
            smart: smartLists,
            custom: customLists,
            total: smartLists.length + customLists.length,
        }),
        {
            status: 200,
            headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
        },
    );
});
