/// <reference lib="deno.ns" />
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createSupabaseServiceClient } from "../_shared/supabaseClient.ts";
import { getValidAccessToken } from "../_shared/tokenManager.ts";
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

    // 2) Token laden mit automatischer Erneuerung
    const { token: accessToken, error: tokenError } = await getValidAccessToken(
        supabase,
        creator_id
    );

    console.log(`tokenError: ${tokenError || "null"}`);
    console.log(`hasToken: ${accessToken ? "yes" : "no"}`);

    if (tokenError || !accessToken) {
        return new Response(
            JSON.stringify({
                error: tokenError || "No access token available",
                creator_id,
                needsReconnect: tokenError?.includes("reconnect") || tokenError?.includes("refresh"),
            }),
            {
                status: 401,
                headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
            },
        );
    }

    const creatorUserUuid = String(creator.fanvue_creator_id);

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
    let usedFallback = false;
    try {
        smartListsRaw = await getSmartListsRest(accessToken, creatorUserUuid);
        console.log(`smartListsRaw.length=${smartListsRaw.length}`);
        // Log the first smart list to see what data we're getting
        if (smartListsRaw.length > 0) {
            console.log(`smartListsRaw[0] FULL: ${JSON.stringify(smartListsRaw[0])}`);
        }
    } catch (err) {
        console.warn("smart lists api not available, fallback. Error:", err);
    }

    if (smartListsRaw.length === 0) {
        smartListsRaw = KNOWN_SMART_LISTS;
        usedFallback = true;
        console.warn("⚠️ Using KNOWN_SMART_LISTS fallback - counts will be 0");
    }

    // Map smart lists - count direkt von API übernehmen
    // Die /chats/lists/smart API sollte count pro Liste liefern
    const smartLists: AudienceList[] = smartListsRaw.map((sl: any) => {
        const count = Number(sl.count ?? 0);
        console.log(`Smart list ${sl.type}: count=${count}`);
        return {
            id: String(sl.type),
            name: String(sl.name),
            fanCount: count,
            type: "smart" as const,
        };
    });

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
            _debug: {
                usedSmartListFallback: usedFallback,
                smartListsFromApi: !usedFallback,
            },
        }),
        {
            status: 200,
            headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
        },
    );
});
