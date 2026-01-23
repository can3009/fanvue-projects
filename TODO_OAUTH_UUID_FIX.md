# TODO: Automatic Fanvue UUID Extraction from OAuth

The goal is to automatically extract the real Fanvue UUID (from the `sub` claim in the JWT access token) during the OAuth flow and update the `creators` table. This prevents manual entry errors where users enter their username instead of the UUID.

## Plan

1.  **Modify `supabase/functions/oauth-callback/index.ts`**
    *   Add a helper function `extractUserIdFromToken` to decode the JWT.
    *   After the successful token exchange with Fanvue, parse the `access_token`.
    *   Extract the `sub` field (which is the UUID).

2.  **Update Database**
    *   In the same callback function, perform a database update:
        ```typescript
        await supabase.from("creators").update({
          fanvue_creator_id: fanvueUserId
        }).eq("id", creator_id);
        ```

## Helper Function Snippet

```typescript
function extractUserIdFromToken(accessToken: string): string | null {
  try {
    const parts = accessToken.split('.');
    if (parts.length !== 3) return null;
    
    // Decode base64url
    const base64 = parts[1].replace(/-/g, '+').replace(/_/g, '/');
    const jsonPayload = decodeURIComponent(atob(base64).split('').map(function(c) {
        return '%' + ('00' + c.charCodeAt(0).toString(16)).slice(-2);
    }).join(''));

    const payload = JSON.parse(jsonPayload);
    return payload.sub || null;
  } catch (e) {
    console.error("Failed to decode token:", e);
    return null;
  }
}
```

## Why this is needed
The Fanvue API requires the UUID (e.g., `2a149881...`) for endpoints like `/creators/{uuid}/chats/lists`. The username (e.g., `amara.veyra`) does not work. Automatically syncing this during OAuth ensures the correct ID is always used.
