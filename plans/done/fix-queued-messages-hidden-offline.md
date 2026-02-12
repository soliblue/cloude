<!-- build: 71 -->
# Fix: Queued messages invisible when sent offline

**Status:** testing
**Created:** 2026-02-12

## Problem
When sending a message while disconnected, it disappears until reconnection. The message gets queued to `pendingMessages` correctly, but the UI hides it because `showEmptyState` in `ChatMessageList` doesn't account for queued messages.

## Root Cause
`ConversationView+Components.swift` — `showEmptyState` only checks `messages.isEmpty`, not `queuedMessages.isEmpty`. On new/empty conversations, `showEmptyState` becomes `true`, which hides the entire scroll view (including `queuedMessagesSection`).

## Fix
Added `queuedMessages.isEmpty` to the `showEmptyState` condition so queued messages prevent the empty state from showing.

## Files Changed
- `Cloude/Cloude/UI/ConversationView+Components.swift` — line 100

## Test
1. Disconnect from Mac agent
2. Send a message in a new (empty) conversation
3. Queued message bubble should appear immediately (swipeable to delete)
4. Reconnect — message should send and response should stream
