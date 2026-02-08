# Fix Silent Message Drop {exclamationmark.bubble}

> Messages disappear when sendConversationMessage silently returns but sendMessage always clears inputText.

## Problem

`sendMessage()` unconditionally clears `inputText` after calling `sendConversationMessage()`, even when the message was silently dropped. Three silent exit points in `sendConversationMessage`:

1. `guard let activeWindow` — nil if activeWindowId stale + at 5 window limit
2. `guard let conv` — conversation lookup fails (unlikely)
3. Cost limit check — `conv.totalCost >= limit` returns without queuing

User types message, taps send, text vanishes from input bar, nothing appears in chat.

## Goals
- Never lose user input silently
- Show feedback when a message can't be sent
- Cost-limited conversations should queue or show clear feedback

## Approach
- Make `sendConversationMessage` and `sendHeartbeatMessage` return `Bool`
- Only clear `inputText`/`attachedImages`/`drafts` in `sendMessage()` when return is `true`
- Cost limit path: either queue the message (like isRunning path) or show a toast/banner
- Guard failures: restore input text if somehow reached

## Files
- `Cloude/Cloude/UI/MainChatView+Messaging.swift` — core fix
- `Cloude/Cloude/UI/ConversationView+Components.swift` — cost banner (already exists at 75%)
