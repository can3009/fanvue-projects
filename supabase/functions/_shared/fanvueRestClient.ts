// supabase/functions/_shared/fanvueRestClient.ts
/// <reference lib="deno.ns" />

/**
 * Fanvue REST API Client (Agency/Multi-Creator)
 *
 * IMPORTANT:
 * - We try MULTIPLE endpoint variants because Fanvue differs per account/version.
 * - We auto-detect pagination styles (nextCursor vs pagination.hasMore vs none).
 */

export interface FanvueCustomList {
    uuid: string;
    name: string;
    membersCount: number;
    createdAt?: string;
}

export interface FanvueSmartList {
    type: string;
    name: string;
    description?: string;
    count?: number;
}

const BASE_URL = "https://api.fanvue.com";
const API_VERSION = "2025-06-26";

function authHeaders(accessToken: string): HeadersInit {
    return {
        Authorization: `Bearer ${accessToken}`,
        "X-Fanvue-API-Version": API_VERSION,
        "Content-Type": "application/json",
    };
}

/**
 * Extract items + nextCursor from many possible shapes
 */
function extractItemsAndCursor(rawJson: any): { items: any[]; nextCursor: number | null } {
    // Possible shapes we handle:
    // 1) { data: [...], pagination: { hasMore: true } }   -> cursor null, items data
    // 2) { items: [...], nextCursor: 15 }                 -> cursor 15, items
    // 3) { data: { items: [...], nextCursor: 15 } }       -> cursor 15, items
    // 4) { result: { data: { json: { items, nextCursor }}}} (tRPC-like) -> cursor, items
    const directItems = rawJson?.items;
    const directCursor = rawJson?.nextCursor;

    if (Array.isArray(directItems)) {
        return { items: directItems, nextCursor: typeof directCursor === "number" ? directCursor : null };
    }

    const dataItems = rawJson?.data?.items;
    const dataCursor = rawJson?.data?.nextCursor;
    if (Array.isArray(dataItems)) {
        return { items: dataItems, nextCursor: typeof dataCursor === "number" ? dataCursor : null };
    }

    const dataArray = rawJson?.data;
    if (Array.isArray(dataArray)) {
        return { items: dataArray, nextCursor: null };
    }

    const trpcItems = rawJson?.result?.data?.json?.items;
    const trpcCursor = rawJson?.result?.data?.json?.nextCursor;
    if (Array.isArray(trpcItems)) {
        return { items: trpcItems, nextCursor: typeof trpcCursor === "number" ? trpcCursor : null };
    }

    // fallback
    return { items: [], nextCursor: null };
}

/**
 * Get Custom Lists (tries multiple endpoint variants)
 */
export const getCustomListsRest = async (
    accessToken: string,
    creatorUserUuid?: string | null,
): Promise<FanvueCustomList[]> => {
    // Candidate endpoints (try in order)
    const candidates: string[] = [];

    if (creatorUserUuid) {
        candidates.push(`${BASE_URL}/creators/${encodeURIComponent(creatorUserUuid)}/chats/lists/custom`);
    }

    // Common "global" variant
    candidates.push(`${BASE_URL}/chats/lists/custom`);

    let lastError: unknown = null;

    for (const base of candidates) {
        try {
            console.log(`📋 [REST] Trying custom lists base: ${base}`);

            const all: FanvueCustomList[] = [];

            // We will try cursor pagination first if server returns nextCursor,
            // otherwise try page/size if server returns pagination.hasMore,
            // otherwise single-shot.
            let mode: "unknown" | "cursor" | "page" | "single" = "unknown";
            let cursor: number | null = null;
            let page = 1;
            const size = 50;

            for (let i = 0; i < 50; i++) {
                let url = base;

                if (mode === "cursor") {
                    // some APIs accept cursor param
                    url = `${base}?cursor=${encodeURIComponent(String(cursor ?? 0))}&direction=forward`;
                } else if (mode === "page") {
                    url = `${base}?page=${page}&size=${size}`;
                } else if (mode === "unknown") {
                    // first request: no params
                    url = base;
                } else if (mode === "single") {
                    break;
                }

                console.log(`📋 [REST] GET ${url}`);

                const resp = await fetch(url, {
                    method: "GET",
                    headers: authHeaders(accessToken),
                });

                const raw = await resp.text();
                console.log(`📋 [REST] Response (${resp.status}): ${raw.substring(0, 1000)}`);

                if (!resp.ok) {
                    throw new Error(`Custom lists failed ${resp.status}: ${raw}`);
                }

                const json = JSON.parse(raw);

                const { items, nextCursor } = extractItemsAndCursor(json);

                // If the API returns { data: [...] } already (array), extractItemsAndCursor returns empty.
                // In that case, accept data array.
                const dataArray = Array.isArray(json?.data) ? json.data : null;
                const pageItems = (items.length > 0 ? items : dataArray) ?? [];

                // Detect mode after first response
                if (mode === "unknown") {
                    if (typeof nextCursor === "number") mode = "cursor";
                    else if (json?.pagination && typeof json.pagination?.hasMore === "boolean") mode = "page";
                    else mode = "single";
                }

                // Map items to FanvueCustomList shape
                const mapped = pageItems.map((x: any) => ({
                    uuid: String(x.uuid ?? x.id ?? ""),
                    name: String(x.name ?? ""),
                    membersCount: Number(x.membersCount ?? x.members_count ?? 0),
                    createdAt: x.createdAt ?? x.created_at,
                })) as FanvueCustomList[];

                // filter invalid
                const valid = mapped.filter((x) => x.uuid && x.name);
                all.push(...valid);

                if (mode === "cursor") {
                    if (typeof nextCursor === "number") {
                        cursor = nextCursor;
                        continue;
                    }
                    // no nextCursor -> done
                    break;
                }

                if (mode === "page") {
                    const hasMore = json.pagination?.hasMore === true;
                    if (hasMore) {
                        page++;
                        continue;
                    }
                    break;
                }

                // single-shot
                break;
            }

            console.log(`✅ [REST] Parsed ${all.length} custom lists total from ${base}`);
            return all;
        } catch (e) {
            lastError = e;
            console.warn(`⚠️ [REST] Custom lists failed for ${base}:`, e);
            // try next candidate
        }
    }

    throw lastError ?? new Error("Custom lists failed on all endpoint variants");
};

/**
 * Get Smart Lists (tries multiple endpoint variants)
 */
export const getSmartListsRest = async (
    accessToken: string,
    creatorUserUuid?: string | null,
): Promise<FanvueSmartList[]> => {
    const candidates: string[] = [];

    if (creatorUserUuid) {
        candidates.push(`${BASE_URL}/creators/${encodeURIComponent(creatorUserUuid)}/chats/lists/smart`);
    }

    candidates.push(`${BASE_URL}/chats/lists/smart`);

    let lastError: unknown = null;

    for (const url of candidates) {
        try {
            console.log(`📋 [REST] GET ${url}`);

            const resp = await fetch(url, {
                method: "GET",
                headers: authHeaders(accessToken),
            });

            const raw = await resp.text();
            console.log(`📋 [REST] Response (${resp.status}): ${raw.substring(0, 1000)}`);

            if (!resp.ok) {
                // smart lists optional -> try next
                lastError = new Error(`Smart lists failed ${resp.status}: ${raw}`);
                continue;
            }

            const json = JSON.parse(raw);

            // Possible: { data: [...] } or { items: [...] } or direct array
            const data = Array.isArray(json) ? json : (json.data ?? json.items ?? json.result?.data?.json?.items ?? []);
            const arr = Array.isArray(data) ? data : [];

            const mapped: FanvueSmartList[] = arr
                .map((x: any) => ({
                    type: String(x.type ?? x.id ?? ""),
                    name: String(x.name ?? ""),
                    description: x.description,
                    count: Number(x.count ?? x.membersCount ?? 0),
                }))
                .filter((x: FanvueSmartList) => x.type && x.name);

            console.log(`✅ [REST] Parsed ${mapped.length} smart lists from ${url}`);
            return mapped;
        } catch (e) {
            lastError = e;
            console.warn(`⚠️ [REST] Smart lists failed for ${url}:`, e);
        }
    }

    // smart lists can fallback
    console.warn("⚠️ [REST] Smart lists failed on all variants; returning empty");
    if (lastError) console.warn("Last smart list error:", lastError);
    return [];
};

/**
 * Known Smart List Types (static fallback)
 */
export const KNOWN_SMART_LISTS: FanvueSmartList[] = [
    { type: "ALL_CONTACTS", name: "All contacts", count: 0 },
    { type: "ONLINE", name: "Online", count: 0 },
    { type: "FOLLOWERS", name: "Followers", count: 0 },
    { type: "SUBSCRIBERS", name: "Subscribers", count: 0 },
    { type: "NON_RENEWING", name: "Non-renewing", count: 0 },
    { type: "AUTO_RENEWING", name: "Auto-renewing", count: 0 },
    { type: "EXPIRED_SUBSCRIBERS", name: "Expired subscribers", count: 0 },
    { type: "FREE_TRIAL_SUBSCRIBERS", name: "Free trial subscribers", count: 0 },
    { type: "SPENT_MORE_THAN", name: "Spent more than $50", count: 0 },
];
