# Fix Silent Message Drop {exclamationmark.bubble}
<!-- priority: 2 -->
<!-- tags: messages, ui -->

> Messages disappear after switching windows — sent message doesn't show in chat and Claude doesn't receive it.

## Problem

User reports: "switch to a different window, switch back, send a message — it disappears. Click refresh, then send — it works."

### Root Cause (most likely)

**Window cleanup causes conversation/window mismatch.** When switching windows, `cleanupEmptyConversation` deletes empty conversations and unlinks them from windows. If the user switches away from a new/empty window and back:

1. Switch away → `cleanupEmptyConversation` deletes conv, calls `unlinkConversation` → `window.conversationId = nil`
2. Switch back → `pagedWindowContent` passes `conversation: nil` to `ConversationView`
3. `ConversationView.effectiveConversation` falls back to `store.currentConversation` (a DIFFERENT conversation)
4. User sends → `sendConversationMessage` sees `activeWindow.conversationId == nil` → creates NEW conversation
5. Message goes to new conversation, but view is showing `currentConversation` → message appears lost

Additionally, `cleanupEmptyConversation` at line 57 can `removeWindow`, shifting `ForEach` indexes and causing `currentPageIndex` to point to the wrong window.

### Secondary Issue

`sendMessage()` unconditionally clears `inputText` after `sendConversationMessage()`, even when the message was silently dropped (cost limit, nil window). Three silent exit points with no user feedback.

### Why Refresh Fixes It

`refreshMissedResponse` calls `syncHistory` which fetches the real message history from the CLI session file on disk and calls `replaceMessages`, re-populating the conversation. This re-aligns the view with reality.

## Goals
- Never lose user input silently
- Window switching should not orphan conversations from their views
- Show feedback when a message can't be sent

## Approach

### Fix 1: Don't unlink conversations that are running
```swift
func cleanupEmptyConversation(for windowId: UUID) {
    guard let window = ...,
          let conversation = ...,
          conversation.isEmpty,
          !connection.output(for: convId).isRunning  // NEW: don't touch running convs
    else { return }
```

### Fix 2: Make send functions return Bool
- `sendConversationMessage` and `sendHeartbeatMessage` return `Bool`
- Only clear `inputText`/`attachedImages`/`drafts` when return is `true`

### Fix 3: Move finalizeStreamingMessage out of the view
`handleCompletion` / `finalizeStreamingMessage` only runs inside `ConversationView`. If the view is off-screen in a TabView, it may not fire. Move this to the app level or `ConnectionManager` so responses always get persisted regardless of which window is visible.

## Files
- `Cloude/Cloude/UI/MainChatView+Messaging.swift` — send return value fix
- `Cloude/Cloude/UI/MainChatView+Utilities.swift` — cleanupEmptyConversation guard
- `Cloude/Cloude/UI/MainChatView.swift` — window cleanup in onChange(currentPageIndex)
- `Cloude/Cloude/UI/ConversationView.swift` — handleCompletion (move to app level)
- `Cloude/Cloude/App/CloudeApp.swift` — add global completion handler

## Open Questions
- Should empty conversation cleanup be removed entirely? It auto-deletes conversations that might have just been created.
- Should `ConversationView.effectiveConversation` never fall back to `currentConversation`? Return nil instead?
