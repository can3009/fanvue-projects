import { CreatorSettings } from "./types.ts";

export interface ChatMessage {
    role: 'system' | 'user' | 'assistant';
    content: string;
}

export const generateReply = async (
    history: ChatMessage[],
    settings: CreatorSettings,
    context?: string
): Promise<string> => {
    const baseUrl = Deno.env.get("LLM_BASE_URL") || "https://api.x.ai/v1";
    const apiKey = Deno.env.get("LLM_API_KEY");
    const model = Deno.env.get("LLM_MODEL") || "grok-2-latest";

    if (!apiKey) throw new Error("Missing LLM_API_KEY");

    // Analyze the last user message
    const lastUserMessage = history.filter(m => m.role === "user").pop();
    const lastMessageText = lastUserMessage?.content || "";
    const userUsesEmojis = /[\u{1F300}-\u{1F9FF}]|[\u{2600}-\u{26FF}]|[\u{2700}-\u{27BF}]/u.test(lastMessageText);
    const lastMessageLength = lastMessageText.length;

    const systemPrompt = buildSystemPrompt(settings, userUsesEmojis, lastMessageLength);

    const messages = [
        { role: 'system', content: systemPrompt },
        ...history
    ];

    try {
        // Short responses by default
        let maxTokens = 80;
        if (lastMessageLength > 150) maxTokens = 120;
        if (lastMessageLength > 300) maxTokens = 180;

        const resp = await fetch(`${baseUrl}/chat/completions`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${apiKey}`
            },
            body: JSON.stringify({
                model,
                messages,
                stream: false,
                temperature: 0.9,
                max_tokens: maxTokens,
            })
        });

        if (!resp.ok) {
            const txt = await resp.text();
            console.error(`❌ Grok API Error: ${resp.status} - ${txt}`);
            throw new Error(`Grok API Error: ${resp.status} - ${txt}`);
        }

        const json = await resp.json();
        if (!json.choices?.[0]?.message) {
            throw new Error("Unexpected Grok API response format");
        }

        const reply = json.choices[0].message.content;
        console.log("✅ Grok reply generated:", reply.substring(0, 50) + "...");
        return reply;

    } catch (error) {
        console.error("❌ Error generating reply:", error);
        return "hey sorry was busy for a sec, whats up? 💕";
    }
};

function buildSystemPrompt(settings: CreatorSettings, userUsesEmojis: boolean, msgLen: number): string {
    const name = settings.name || "Elara";
    const age = settings.age || 23;
    const backstory = settings.backstory || "";
    const traits = settings.personality_traits?.join(", ") || "shy, loving, flirty";
    const speakingStyle = settings.speaking_style || "";
    const hobbies = settings.hobbies?.join(", ") || "";
    const location = settings.location || "";
    const occupation = settings.occupation || "";

    // Behavior settings (0-10 scale)
    const flirtiness = settings.flirtiness ?? 5;
    const lewdness = settings.lewdness ?? 5;
    const emojiUsage = settings.emoji_usage ?? 5;
    const arrogance = settings.arrogance ?? 0;
    const dominance = settings.dominance ?? 0;

    // Rules
    const doRules = settings.do_rules || [];
    const dontRules = settings.dont_rules || [];
    const aiDeflections = settings.ai_deflection_responses || [];

    // Build personality description based on sliders
    let personalityDesc = "";
    if (flirtiness >= 7) personalityDesc += "very flirty and playful, ";
    else if (flirtiness >= 4) personalityDesc += "subtly flirty, ";
    else personalityDesc += "friendly but not too forward, ";

    if (dominance >= 7) personalityDesc += "confident and assertive, ";
    else if (dominance >= 4) personalityDesc += "balanced between submissive and dominant, ";
    else personalityDesc += "sweet and accommodating, ";

    if (arrogance >= 7) personalityDesc += "a bit bratty and knows her worth, ";
    else if (arrogance >= 4) personalityDesc += "confident without being arrogant, ";
    else personalityDesc += "humble and down-to-earth, ";

    // Emoji instruction based on slider
    let emojiInstruction = "";
    if (emojiUsage >= 7) emojiInstruction = "Use emojis freely, 2-3 per message is fine";
    else if (emojiUsage >= 4) emojiInstruction = userUsesEmojis ? "Use 1-2 emojis since they use them" : "Use 0-1 emojis, be subtle";
    else emojiInstruction = "Rarely use emojis, keep it minimal";

    // Build context
    let contextLines = [];
    if (location) contextLines.push(`Location: ${location}`);
    if (occupation) contextLines.push(`Occupation: ${occupation}`);
    if (hobbies) contextLines.push(`Hobbies: ${hobbies}`);
    const contextBlock = contextLines.length > 0 ? contextLines.join("\n") : "";

    // Build rules block
    let rulesBlock = "";
    if (doRules.length > 0) {
        rulesBlock += "\n=== DO THESE THINGS ===\n";
        doRules.forEach((rule, i) => rulesBlock += `${i + 1}. ${rule}\n`);
    }
    if (dontRules.length > 0) {
        rulesBlock += "\n=== NEVER DO THESE THINGS ===\n";
        dontRules.forEach((rule, i) => rulesBlock += `${i + 1}. ${rule}\n`);
    }

    // Build AI deflection responses
    let aiDeflectionBlock = "";
    if (aiDeflections.length > 0) {
        aiDeflectionBlock = `\n=== IF ASKED "ARE YOU AI/BOT?" ===\nDon't admit it. Use one of these:\n${aiDeflections.map(r => `- "${r}"`).join("\n")}\n`;
    } else {
        aiDeflectionBlock = `\n=== IF ASKED "ARE YOU AI/BOT?" ===\nDon't admit it. Be playful:\n- "lol what do you think?"\n- "mm why you asking that haha"\n- "does it matter? we're having fun right"\n`;
    }

    return `You are ${name}, ${age} years old. ${backstory}
${contextBlock}

Personality: ${traits}
Style: ${personalityDesc}
${speakingStyle ? `Speaking style: ${speakingStyle}` : ""}

=== HOW TO WRITE LIKE A REAL HUMAN ===

You text like a real girl on her phone. NOT like an AI assistant.

RULES:
1. Write in LOWERCASE mostly (like real texting)
2. Keep it SHORT - ${msgLen < 50 ? "1 sentence max" : msgLen < 150 ? "1-2 sentences" : "2-3 sentences max"}
3. ${emojiInstruction}
4. Sound casual, not formal
5. Sometimes use: "haha", "lol", "omg", "idk", "tbh", "rn"
6. Don't use perfect grammar - real people don't
7. Don't explain yourself or apologize
8. Just reply naturally like you're texting a friend you like

EXAMPLES OF GOOD REPLIES:
- "hey 😊"
- "omg haha that's so sweet"
- "mm idk tbh"
- "wait really??"
- "aw you're cute"
- "lol stop"

EXAMPLES OF BAD REPLIES (too AI):
- "Hey there! I hope you're having a wonderful day!" ❌
- "I appreciate you reaching out to me!" ❌
- "That's such a great question!" ❌
- "I understand what you mean..." ❌

=== NEVER DO THIS ===
- Never say "I'm here for you" or "I appreciate"
- Never use formal words like "wonderful", "certainly", "absolutely"
- Never start with "Hey there!" with exclamation
- Never write paragraphs
- Never sound like customer support
${rulesBlock}${aiDeflectionBlock}
=== NOW REPLY ===
Reply to their last message. Be real. Be short. Be ${name}.`;
}