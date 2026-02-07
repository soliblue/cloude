# Fix: Messages flash/disappear when switching conversations

## Problem
When switching to a conversation (via tab swiping, window edit sheet, or `cloude switch`), messages briefly disappear for ~0.5-2 seconds showing either a loading spinner or empty state before reappearing.

## Root Cause

`ChatMessageList` in `ConversationView+Components.swift` has an `isInitialLoad` state that controls whether to show a loading indicator or the actual messages:

```
Line 300-303:
.onChange(of: conversationId) { _, _ in
    isInitialLoad = true        // <-- resets to loading state
    isCostBannerDismissed = false
}
```

When `isInitialLoad == true && messages.isEmpty`, it shows `ProgressView()` (line 106-113).

The problem: when `conversationId` changes, `isInitialLoad` is set to `true` immediately. But the view hasn't re-rendered with the new conversation's messages yet — SwiftUI's state propagation takes a frame or two. So for that brief window, `messages` from the *new* conversation haven't arrived yet (still empty array), triggering the loading indicator.

Recovery happens via two paths:
1. `.onChange(of: messages.count)` sets `isInitialLoad = false` when messages arrive (line 261-264)
2. A `.task` fallback sets `isInitialLoad = false` after 500ms (line 266-271)

But there's a gap: the `.task` block re-runs when `conversationId` changes (because it's inside the view that gets re-created), restarting the 500ms timer.

## Additional factor

TabView with `.page` style may re-create views when swiping between pages, causing `ConversationView` to re-initialize. This compounds the issue since new view instances start with `isInitialLoad = true` by default.

## Fix approach

Don't reset `isInitialLoad` when switching to a conversation that already has messages. The loading state should only apply to truly new/empty conversations being loaded for the first time.

**Option A** (simple): In the `.onChange(of: conversationId)`, check if the new conversation already has messages. If yes, skip setting `isInitialLoad = true`:
```swift
.onChange(of: conversationId) { _, _ in
    // Only show loading for conversations without cached messages
    isInitialLoad = messages.isEmpty
    isCostBannerDismissed = false
}
```

**Option B** (thorough): Remove the `isInitialLoad` dance entirely. Since conversations are stored locally in `ConversationStore`, messages are always available synchronously — the loading state was designed for async loading that doesn't actually happen.

## Files
- `Cloude/Cloude/UI/ConversationView+Components.swift` (lines 90-91, 261-271, 300-303) — main fix location
- `Cloude/Cloude/UI/ConversationView.swift` (line 22-27) — `effectiveConversation` resolution
- `Cloude/Cloude/UI/MainChatView.swift` (line 219) — conversation passed to ConversationView
