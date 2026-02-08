# Fix: Messages flash/disappear when switching conversations
<!-- priority: 10 -->
<!-- tags: conversations -->
<!-- build: 56 -->

## Problem
When switching to a conversation (via tab swiping, window edit sheet, or `cloude switch`), messages briefly disappear for ~0.5-2 seconds showing either a loading spinner or empty state before reappearing.

## Root Cause (4 triggers)

1. **Unconditional `isInitialLoad` reset**: `.onChange(of: conversationId)` always sets `isInitialLoad = true`, even when the new conversation already has cached messages.
2. **TabView page-style view recreation**: SwiftUI's `.page` TabView destroys/recreates non-adjacent views. Fresh `@State isInitialLoad = true`, and `.onChange(of: messages.count)` only fires on change, not initial value.
3. **Window type switching**: `switch window.type` conditionally includes `ConversationView`. Switching away from `.chat` and back creates a new instance with fresh `isInitialLoad = true`.
4. **Drag gesture interaction**: Page TabView's horizontal swipe can trigger view recreation when scroll gestures get reinterpreted as page changes.

## Fix (3 changes in ConversationView+Components.swift)

1. `.onAppear` — immediately set `isInitialLoad = false` if messages exist (handles triggers 2, 3, 4)
2. `.onChange(of: conversationId)` — conditional: `isInitialLoad = messages.isEmpty` instead of always `true` (handles trigger 1)
3. `.task` → `.task(id: conversationId)` — check messages immediately, only sleep 300ms if truly empty (conversation-aware fallback)

Confirmed by Codex review: no timing risk since messages are stored synchronously (UserDefaults-backed @Published).
