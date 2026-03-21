# Smart Conversation Naming {character.cursor.ibeam}
<!-- priority: 10 -->
<!-- tags: conversations -->

> Auto-name conversations via a background Sonnet call on first message, appearing in ~1-2s instead of ~5-10s.

## Summary
When a user sends their first message in a new conversation, fire a separate background CLI call (Sonnet) to generate a conversation name + SF Symbol. This runs in parallel with the actual agent — the name appears almost immediately instead of waiting for the agent to call `cloude rename`.

## Why
Currently naming only happens when the agent decides to call `cloude rename` + `cloude symbol`, which:
- Requires the agent to be running first
- Depends on CLAUDE.md instructions (fragile)
- Adds latency — name shows up seconds into the response
- Doesn't work for conversations that error out early

## Architecture

### Flow
1. User sends first message in a new conversation
2. iOS immediately sends `suggest_name` request to Mac agent with the message text
3. Mac agent spawns a lightweight CLI call: `claude --model sonnet -p "Given this message, suggest a 1-2 word conversation name and an SF Symbol..."`
4. CLI returns name + symbol as structured output
5. Mac agent sends `name_suggestion` back to iOS
6. iOS updates the conversation name/symbol in the header — smooth transition from default name

### Display
- Conversation starts with its random default name (Spark, Nova, etc.)
- When suggestion arrives, crossfade to the new name in the header
- The name is treated as a suggestion — the agent can still override it later via `cloude rename`
- If the agent also calls `cloude rename`, that takes priority (last write wins)

### What about the existing `cloude rename` flow?
- Keep it. The agent can still rename at any point
- The background naming is a fast first pass; agent rename is the authoritative override
- This means first message gets a name in ~1-2s instead of ~5-10s

## Implementation

### 1. Shared Protocol (CloudeShared)

**ClientMessage** — add:
```swift
case suggestName(text: String, conversationId: String)
```

**ServerMessage** — add:
```swift
case nameSuggestion(name: String, symbol: String?, conversationId: String)
```

### 2. Mac Agent — NameSuggestionService

New file or add to existing service. Spawns CLI one-shot:
- `claude --model sonnet -p "..." --output-format text --max-turns 1`
- Prompt asks for JSON: `{"name": "Short Name", "symbol": "sf.symbol.name"}`
- Parse the response, extract name + symbol
- Timeout: 5 seconds
- If it fails or times out, silently ignore — the default name stays

### 3. Mac Agent — Message Handling
Add case for `.suggestName` → spawn background CLI → send `.nameSuggestion` back

### 4. iOS — ConnectionManager
- Add `requestNameSuggestion(text:conversationId:)` method
- Handle `.nameSuggestion` — call existing rename/symbol update handlers

### 5. iOS — MainChatView+Messaging
- In `sendMessage()`, after sending the chat, check if conversation is new (no sessionId yet / first message)
- If so, fire `connection.requestNameSuggestion(text:conversationId:)`

### 6. iOS — Header Animation
- When name suggestion arrives, animate the header transition (crossfade or slide)
- Use existing `onRenameConversation` / `onSetConversationSymbol` handlers

## Files to Modify
1. `CloudeShared/.../ClientMessage.swift` — add `suggestName` case
2. `CloudeShared/.../ServerMessage.swift` — add `nameSuggestion` case
3. `CloudeShared/.../ServerMessage+Encoding.swift` — encode new case
4. `Cloude Agent/Services/AutocompleteService.swift` — add name suggestion (reuse same service for lightweight CLI calls)
5. `Cloude Agent/App/AppDelegate+MessageHandling.swift` — handle suggestName
6. `Cloude/Services/ConnectionManager+API.swift` — send/receive name suggestion
7. `Cloude/UI/MainChatView+Messaging.swift` — trigger on first message
