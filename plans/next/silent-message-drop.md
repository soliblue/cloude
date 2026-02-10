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

## Codex Review

**Findings (highest severity first)**

1. **Window/conversation binding is still fragile if cleanup remains index-driven**
- Risk: `currentPageIndex` + `ForEach` index shifts can still misroute sends even after guarding running conversations.
- Why: Removing a window mutates ordering; page index can now point at a different `windowId`.
- Where: `Cloude/Cloude/UI/MainChatView.swift`, `Cloude/Cloude/UI/MainChatView+Utilities.swift`.
- Improvement: Bind page selection to stable `windowId` (UUID), not array index.

2. **Fix 1 likely addresses only one orphaning path**
- Risk: Empty conversation can still be deleted before first send if not “running” yet.
- Why: New draft conversations are often empty/non-running by design.
- Where: `Cloude/Cloude/UI/MainChatView+Utilities.swift`.
- Improvement: Don’t auto-delete on window switch. Cleanup only on explicit close, app background sweep, or age-based GC.

3. **`Bool` return for send is too lossy for UX and diagnostics**
- Risk: You can’t distinguish “no active window”, “cost limit”, “transport failure”, etc.
- Where: `Cloude/Cloude/UI/MainChatView+Messaging.swift`.
- Improvement: Return `Result<SendAccepted, SendError>` (or typed enum) and surface actionable UI feedback per failure.

4. **Moving completion logic to app level can create double-finalization or lifecycle races**
- Risk: If `ConversationView` and global handler both finalize, message state can be duplicated/corrupted.
- Where: `Cloude/Cloude/UI/ConversationView.swift`, `Cloude/Cloude/App/CloudeApp.swift`.
- Improvement: Single owner for stream lifecycle (prefer model/service layer). Views should render state only.

5. **`effectiveConversation` fallback is a correctness hazard**
- Risk: Cross-window bleed where one window renders/sends against another conversation.
- Where: `Cloude/Cloude/UI/ConversationView.swift`.
- Improvement: Remove fallback to `store.currentConversation` for window-scoped views; render empty/error state when missing binding.

**Missing considerations**

1. **Atomicity/invariants**
- Define invariant: `window.conversationId` must either be valid or UI is non-sendable.
- Add assertions/logging when violated.

2. **Concurrency**
- Ensure mutations to windows/conversations happen on one actor (`@MainActor` or dedicated store actor) to avoid race during switch/send/cleanup.

3. **Observability**
- Add structured events: `window_switched`, `conversation_unlinked`, `send_rejected(reason)`, `send_accepted(conversationId)`.

4. **Regression tests**
- Add tests for: switch-away/switch-back/send; delete window while paged; off-screen streaming completion; cost-limit rejection preserving draft text.

**Suggested plan adjustments**

1. Freeze cleanup behavior first (disable unlink-on-switch), ship guarded hotfix.
2. Refactor page selection to `windowId` identity.
3. Remove `effectiveConversation` fallback for window-scoped rendering.
4. Introduce typed send result + user-visible error handling.
5. Centralize streaming completion in one non-view component.
6. Add targeted integration tests before re-enabling any cleanup policy.
