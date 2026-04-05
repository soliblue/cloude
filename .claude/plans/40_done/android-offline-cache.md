# Android Offline Cache {arrow.down.circle}
<!-- priority: 14 -->
<!-- tags: android, offline -->

> Cache conversations and queue messages for offline use.

## Desired Outcome
Persist conversations locally for offline reading. Queue outgoing messages when disconnected. Auto-send queued messages on reconnect. Show visual indicator for queued messages.

## iOS Reference Architecture

### Components
- `OfflineCacheService.swift` - manages offline message queue and cache
- `ConversationStore+Messaging.swift` - queues messages to `pendingMessages` when not connected
- `ChatMessage.isQueued` flag marks messages awaiting delivery
- On reconnect, pending messages are sent in order and `isQueued` is cleared

### Android implementation notes
- `ChatMessage` already has `isQueued: Boolean` field
- `Conversation` already has `pendingMessages` list
- Need to: detect disconnection in `ConnectionManager`, queue instead of send, flush on reconnect
- Visual indicator in `MessageBubble` for queued messages (clock icon or muted styling)
- `ConversationStore` already persists conversations to disk, so queued messages survive app restart

**Files (iOS reference):** OfflineCacheService.swift, ConversationStore+Messaging.swift
