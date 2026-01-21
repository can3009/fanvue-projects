/// <reference lib="deno.ns" />
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

serve(async (req) => {
    const fanvueUserId = "88d4c02c-bc4b-41a7-bcd5-73bbe5b0381b";
    const accessToken = "eyJhbGciOiJSUzI1NiIsImtpZCI6IjFmMTg5Y2QwLTdhYzUtNDlmZC04ZWQzLTE0MDE5NzlkYjRlNiIsInR5cCI6IkpXVCJ9.eyJhdWQiOlsiaHR0cHM6Ly9hcGkuZmFudnVlLmNvbSJdLCJjbGllbnRfaWQiOiI1YWE1Nzc4MC00YTM1LTQ3ZjQtOWY5Ny1hZWEyYTdkZGY3NDciLCJleHAiOjE3NjkwMDM5MjIsImV4dCI6e30sImlhdCI6MTc2OTAwMDMyMiwiaXNzIjoiaHR0cHM6Ly9hdXRoLmZhbnZ1ZS5jb20iLCJqdGkiOiIxYzc1YzE2MC0wMTBlLTRkODEtOWM1OS00NjViZTU3MjgwM2YiLCJuYmYiOjE3NjkwMDAzMjIsInNjcCI6WyJyZWFkOmNoYXQiLCJ3cml0ZTpjaGF0IiwicmVhZDpzZWxmIiwicmVhZDpjcmVhdG9yIiwicmVhZDpmYW4iLCJyZWFkOm1lZGlhIiwid3JpdGU6bWVkaWEiLCJyZWFkOnBvc3QiLCJ3cml0ZTpwb3N0IiwicmVhZDppbnNpZ2h0cyIsIndyaXRlOmNyZWF0b3IiXSwic3ViIjoiMmExNDk4ODEtYWQ5My00NTU0LTg1OTItMGQ4MWI5ZmM0Y2UzIn0.6YiMTF5PFPkD2WVqAI_iXa_hXDH8Kw4Bp25VqsnnXFdj1GBleCgumFgWEgzuLbhDX9V572cJennn1lEBJrhwXZyO75J9Yvu-M8WYBelkFLYp2glfBRqJYNjm44UzXGbrb_yO9Ldg4BANeBX5pqn59sne3QIhgFPwoM-lBGOjgnVMot4ybaOWCQu4xbbi2nj--7WMaFCAChyoVEkR4O49M3MbY-u7UtgedNZ3bCD_jCkn2e85mg79Qpz-2Dz03nI_vjTNKGmhpk34-C4mzX2hvmeSR2VE5XIBzN4azgUCQD4CLCHbliJ30zkBngqrIc7LsNPrM8XUuKOVCScUfo6Vb7dGsFDcsRNhd-i0fwRUgQeAVS0qSsWmBuEN6b9x5EUKh2_prUfGbb-TSsQ-ipPZlWIqrPupMwYmXvhjbK6F5ayCO6wahyCn23x9X__XMRUn7hw1cjh3J69Lfb3yTm9SHX21TnjS50vDYXNk3nzvv20ZRol4PPMSRJsRHYNcjlffi0jDvd_UEMJX5dV8v8entOMKMLzws5wkrB-QsiCGr5W9PF2CY33IfsT4HM2wvE5NdL7St8DNYwGY7a7eNJsDwqSTxP-G6mzIgkbLBEdyt_dM9FlKf74NvO_9DR0qniEoPmDzu_q5Tg1qvLK6zuU_gG-v2OtVAMhJ06bXi8qJfOU";

    console.log("🧪 Testing markChatAsRead API...");
    console.log("Fan UUID:", fanvueUserId);

    const url = `https://api.fanvue.com/chats/${fanvueUserId}`;

    const response = await fetch(url, {
        method: "PATCH",
        headers: {
            "Authorization": `Bearer ${accessToken}`,
            "X-Fanvue-API-Version": "2025-06-26",
            "Content-Type": "application/json",
        },
        body: JSON.stringify({ isRead: true }),
    });

    console.log("📊 Response Status:", response.status);
    console.log("📊 Response Headers:", Object.fromEntries(response.headers.entries()));

    let responseBody = "";
    try {
        responseBody = await response.text();
        console.log("📊 Response Body:", responseBody);
    } catch (e) {
        console.log("📊 No response body");
    }

    return new Response(JSON.stringify({
        status: response.status,
        ok: response.ok,
        headers: Object.fromEntries(response.headers.entries()),
        body: responseBody,
    }), {
        headers: { "Content-Type": "application/json" },
    });
});
