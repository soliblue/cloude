# WebSocket Timeout & Auto-Reconnect

## Problem
WebSocket connections can go zombie - iOS thinks it's connected but the TCP connection is silently dead (NAT timeout, iOS backgrounding, network switch). The app shows "connected" but nothing works. User has to manually disconnect and reconnect.

## Root Cause
`URLSessionWebSocketTask.receive()` waits forever for the next message. If the connection dies silently (no RST packet), the failure callback never fires and `handleDisconnect()` is never called.

## Solution
Add a response timeout to `EnvironmentConnection`. When we `send()` something and receive nothing back within ~20 seconds, the connection is dead. Disconnect and auto-reconnect.

### Implementation
- Track `lastReceivedAt` in `EnvironmentConnection` - updated on every received message in `receiveMessage()`
- In `send()`, start/reset a timeout timer (~20s)
- On every received message, cancel/reset the timer
- If timer fires: call `disconnect(clearCredentials: false)` then `reconnect()`
- Timer only runs when we've sent something and are waiting - no false disconnects during idle

### Why this over ping/pong
- No protocol changes needed
- No Mac agent changes
- Only triggers when actively waiting for a response
- Previous ping/pong attempt was reverted (caused regressions)
- Simpler - uses the requests we're already making

### Edge cases
- Timer resets on ANY received message, not just the response we're waiting for
- 20s is generous enough for slow remote servers (medina) but catches dead connections
- Idle connections (no sends) don't get timed out
