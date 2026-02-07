# Offline Message Queue

Queue outgoing prompts while disconnected, send automatically when connection is restored. Reuses the existing `pendingMessages` queue — no new persistence or retry logic needed.

## Implementation

**Approach:** Widen the existing "should I queue?" condition from `isRunning` to `isRunning || !isAuthenticated`, and drain queues on reconnection via an `onAuthenticated` callback.

**Files changed:**
- `MainChatView+Messaging.swift` — queue condition: `isRunning || !connection.isAuthenticated` (conversation + heartbeat paths)
- `HeartbeatSheet.swift` — same queue condition for heartbeat sheet send path
- `ConnectionManager.swift` — added `onAuthenticated` callback property
- `ConnectionManager+API.swift` — fire `onAuthenticated` in `handleAuthResult()` on success
- `MainChatView.swift` — wire `onAuthenticated` to drain all conversations with pending messages
- `ConversationStore+Messaging.swift` — guard `replayQueuedMessages` with `connection.isAuthenticated` to prevent drain during disconnect (when `isRunning` flips false)

## Testing

- [ ] Send message while connected → works as before
- [ ] Send while agent busy → queues, drains when done
- [ ] Disconnect, type messages → appear as queued (dimmed at 0.6 opacity)
- [ ] Reconnect → queued messages auto-send
- [ ] Multiple queued messages → combined and sent in order
- [ ] Heartbeat queue works same as conversation queue
