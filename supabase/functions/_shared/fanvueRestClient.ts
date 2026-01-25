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
 * Laut Fanvue Doku: GET /creators/:creatorUserUuid/chats/lists/smart
 * Response ist ein JSON Array mit Objekten die "type", "name", "count" enthalten
 */
export const getSmartListsRest = async (
    accessToken: string,
    creatorUserUuid?: string | null,
): Promise<FanvueSmartList[]> => {
    const candidates: string[] = [];

    // Primär: Creator-spezifischer Endpoint (laut Doku korrekt)
    if (creatorUserUuid) {
        candidates.push(`${BASE_URL}/creators/${encodeURIComponent(creatorUserUuid)}/chats/lists/smart`);
    }

    // Fallback: Globaler Endpoint
    candidates.push(`${BASE_URL}/chats/lists/smart`);

    let lastError: unknown = null;

    for (const url of candidates) {
        try {
            console.log(`📋 [REST] GET Smart Lists: ${url}`);

            const resp = await fetch(url, {
                method: "GET",
                headers: authHeaders(accessToken),
            });

            const raw = await resp.text();
            console.log(`📋 [REST] Smart Lists Response (${resp.status}): ${raw.substring(0, 2000)}`);

            if (!resp.ok) {
                lastError = new Error(`Smart lists failed ${resp.status}: ${raw}`);
                console.warn(`⚠️ [REST] Smart lists endpoint returned ${resp.status}`);
                continue;
            }

            const json = JSON.parse(raw);

            // Debug: Log the response structure
            console.log(`📋 [REST] Response type: ${Array.isArray(json) ? "Array" : typeof json}`);
            console.log(
                `📋 [REST] Response keys: ${typeof json === "object" && json !== null ? Object.keys(json).join(", ") : "N/A"
                }`,
            );

            // Laut Fanvue Doku: Response ist direkt ein Array
            // Aber wir unterstützen auch: { data: [...] }, { items: [...] }, { data: { items: [...] } }
            let arr: any[] = [];

            if (Array.isArray(json)) {
                // Direktes Array (laut Doku)
                arr = json;
                console.log(`📋 [REST] Using direct array, length: ${arr.length}`);
            } else if (Array.isArray(json?.data?.items)) {
                arr = json.data.items;
                console.log(`📋 [REST] Using json.data.items, length: ${arr.length}`);
            } else if (Array.isArray(json?.data)) {
                arr = json.data;
                console.log(`📋 [REST] Using json.data, length: ${arr.length}`);
            } else if (Array.isArray(json?.items)) {
                arr = json.items;
                console.log(`📋 [REST] Using json.items, length: ${arr.length}`);
            } else if (Array.isArray(json?.result?.data?.json?.items)) {
                arr = json.result.data.json.items;
                console.log(`📋 [REST] Using tRPC format, length: ${arr.length}`);
            }

            if (arr.length === 0) {
                console.warn(`⚠️ [REST] Could not extract smart lists array from response`);
                continue;
            }

            // Debug: Log first item to see structure
            if (arr.length > 0) {
                console.log(`📋 [REST] First smart list item: ${JSON.stringify(arr[0])}`);
            }

            const mapped: FanvueSmartList[] = arr
                .map((x: any) => ({
                    type: String(x.type ?? x.id ?? x.uuid ?? ""),
                    name: String(x.name ?? x.title ?? ""),
                    description: x.description,
                    // count kann unter verschiedenen Keys sein
                    count: Number(x.count ?? x.membersCount ?? x.memberCount ?? x.total ?? 0),
                }))
                .filter((x: FanvueSmartList) => x.type && x.name);

            console.log(
                `✅ [REST] Parsed ${mapped.length} smart lists with counts: ${mapped.map((l) => `${l.type}=${l.count}`).join(", ")
                }`,
            );
            return mapped;
        } catch (e) {
            lastError = e;
            console.error(`❌ [REST] Smart lists failed for ${url}:`, e);
        }
    }

    console.warn("⚠️ [REST] Smart lists failed on all variants; returning empty array");
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

/**
 * Get member count for a specific smart list
 * Returns the total count without fetching all members
 */
export const getSmartListMemberCount = async (
    accessToken: string,
    creatorUserUuid: string,
    smartListType: string,
): Promise<number> => {
    // Try the members endpoint with limit=1 to get pagination info with total count
    const url =
        `${BASE_URL}/creators/${encodeURIComponent(creatorUserUuid)}/chats/lists/smart/${encodeURIComponent(smartListType)}/members?limit=1`;

    try {
        console.log(`📊 [REST] GET member count for ${smartListType}: ${url}`);

        const resp = await fetch(url, {
            method: "GET",
            headers: authHeaders(accessToken),
        });

        const raw = await resp.text();
        console.log(`📊 [REST] Member count response (${resp.status}): ${raw.substring(0, 500)}`);

        if (!resp.ok) {
            console.warn(`⚠️ [REST] Member count failed for ${smartListType}: ${resp.status}`);
            return 0;
        }

        const json = JSON.parse(raw);

        // Try to find total count in various response formats
        // Common patterns: { total: N }, { pagination: { total: N } }, { meta: { total: N } }
        const total = json.total ??
            json.pagination?.total ??
            json.meta?.total ??
            json.data?.total ??
            json.count ??
            null;

        if (typeof total === "number") {
            console.log(`✅ [REST] ${smartListType} has ${total} members (from total)`);
            return total;
        }

        // If no total field, try to extract from items array length
        // (only accurate if there's no pagination)
        const { items } = extractItemsAndCursor(json);
        const dataArray = Array.isArray(json?.data) ? json.data : null;
        const allItems = items.length > 0 ? items : (dataArray ?? []);

        // Check if there's more data (pagination)
        const hasMore = json.pagination?.hasMore === true ||
            json.nextCursor != null ||
            json.data?.nextCursor != null;

        if (!hasMore && allItems.length >= 0) {
            console.log(`✅ [REST] ${smartListType} has ${allItems.length} members (from items array, no pagination)`);
            return allItems.length;
        }

        console.warn(`⚠️ [REST] Could not determine count for ${smartListType}, has pagination but no total`);
        return 0;
    } catch (e) {
        console.error(`❌ [REST] Error getting member count for ${smartListType}:`, e);
        return 0;
    }
};

/**
 * Send Mass Message to fans via Fanvue API
 *
 * Laut Fanvue Doku:
 * - Agency/Multi-Creator: POST /creators/:creatorUserUuid/chats/mass-messages
 * - Normal Creator: POST /chats/mass-messages
 *
 * WICHTIG: creatorUserUuid muss eine UUID sein, NICHT ein Handle!
 *
 * Request Body:
 * {
 *   "text": "Message content",
 *   "includedLists": {
 *     "smartListTypes": ["ALL_CONTACTS", "SUBSCRIBERS", ...]   // some accounts
 *     "smartListUuids": ["ALL_CONTACTS", "SUBSCRIBERS", ...]   // other accounts
 *     "customListUuids": ["uuid1", "uuid2", ...]
 *   },
 *   "excludedLists": {
 *     "smartListTypes": [...],
 *     "smartListUuids": [...],
 *     "customListUuids": [...]
 *   }
 * }
 */
export interface MassMessageRequest {
    text: string;
    includedLists: {
        /**
         * IMPORTANT FIX FOR YOUR ERROR (Invalid includedLists):
         * Fanvue is inconsistent: some endpoints accept smartListTypes, others accept smartListUuids.
         * We allow BOTH and we will send BOTH (compat) to prevent “At least one list must be provided”.
         */
        smartListTypes?: string[];
        smartListUuids?: string[];
        customListUuids?: string[];
    };
    excludedLists?: {
        smartListTypes?: string[];
        smartListUuids?: string[];
        customListUuids?: string[];
    };
}

export interface MassMessageResult {
    success: boolean;
    sent?: number;
    failed?: number;
    messageId?: string;
    error?: string;
}

/**
 * Ensures smart-list keys are compatible across Fanvue variations by mirroring values
 * into BOTH smartListTypes and smartListUuids when one of them is present.
 */
function withSmartListCompatibility(req: MassMessageRequest): MassMessageRequest {
    const smartIncluded = req.includedLists.smartListUuids ?? req.includedLists.smartListTypes;

    const includedLists = {
        ...req.includedLists,
        ...(smartIncluded && smartIncluded.length > 0
            ? { smartListUuids: smartIncluded, smartListTypes: smartIncluded }
            : {}),
    };

    const smartExcluded = req.excludedLists?.smartListUuids ?? req.excludedLists?.smartListTypes;

    const excludedLists = req.excludedLists
        ? {
            ...req.excludedLists,
            ...(smartExcluded && smartExcluded.length > 0
                ? { smartListUuids: smartExcluded, smartListTypes: smartExcluded }
                : {}),
        }
        : undefined;

    return { ...req, includedLists, excludedLists };
}

export const sendMassMessage = async (
    accessToken: string,
    creatorUserUuid: string,
    request: MassMessageRequest,
): Promise<MassMessageResult> => {
    // Try multiple endpoint variants:
    // 1. Agency/Multi-Creator: POST /creators/:uuid/chats/mass-messages
    // 2. Creator's own token: POST /chats/mass-messages
    const endpoints: string[] = [];

    // Validate UUID format
    const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    if (uuidRegex.test(creatorUserUuid)) {
        // Agency endpoint first (if UUID is valid)
        endpoints.push(`${BASE_URL}/creators/${encodeURIComponent(creatorUserUuid)}/chats/mass-messages`);
    }

    // Always try the direct creator endpoint as fallback
    endpoints.push(`${BASE_URL}/chats/mass-messages`);

    console.log(`📤 [REST] Will try ${endpoints.length} endpoint(s) for mass message`);

    let lastError: string | null = null;

    // Apply compatibility fix ONCE (minimal change, directly related to the 400 error)
    const finalRequest = withSmartListCompatibility(request);

    for (const url of endpoints) {
        console.log(`📤 [REST] POST Mass Message: ${url}`);
        console.log(`📤 [REST] Request body: ${JSON.stringify(finalRequest)}`);

        try {
            const resp = await fetch(url, {
                method: "POST",
                headers: authHeaders(accessToken),
                body: JSON.stringify(finalRequest),
            });

            const raw = await resp.text();
            console.log(`📤 [REST] Mass Message Response (${resp.status}): ${raw.substring(0, 1000)}`);

            if (!resp.ok) {
                // Parse error message if possible
                let errorMsg = `Mass message failed ${resp.status}: ${raw}`;
                try {
                    const errJson = JSON.parse(raw);
                    // keep it minimal: extract message if present
                    errorMsg = errJson.message || errJson.error || errorMsg;
                } catch (_) {
                    // ignore parse errors
                }

                console.warn(`⚠️ [REST] Endpoint ${url} failed: ${errorMsg}`);
                lastError = errorMsg;

                // If 404 "not assigned to team member", try next endpoint
                if (resp.status === 404 && errorMsg.includes("not assigned")) {
                    console.log(`📤 [REST] Trying next endpoint...`);
                    continue;
                }

                // For other errors, also try next endpoint
                continue;
            }

            const json = JSON.parse(raw);
            console.log(`✅ [REST] Mass message sent successfully via ${url}`);

            return {
                success: true,
                sent: json.sent ?? json.successCount ?? json.count ?? 0,
                failed: json.failed ?? json.failureCount ?? 0,
                messageId: json.messageId ?? json.id ?? json.uuid,
            };
        } catch (e) {
            console.error(`❌ [REST] Mass message error for ${url}:`, e);
            lastError = String(e);
        }
    }

    // All endpoints failed
    console.error(`❌ [REST] All mass message endpoints failed`);
    return {
        success: false,
        error: lastError || "All endpoints failed",
    };
};
