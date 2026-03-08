# Parallel Environment Connections

Connect to all environments simultaneously instead of one at a time. Stream responses from multiple machines in parallel.

## Why
Multi-agent support already exists (add/switch servers). But switching disconnects from the previous one. With Medina + Mac both running, you should be able to chat on both at the same time across different windows.

## Changes

### ConnectionManager pool
- One WebSocket connection per environment, all live simultaneously
- Replace single active connection with a connection pool
- Each conversation routes messages to its environment's connection
- RunningConversationId becomes per-connection, not global

### Per-environment state
- HeartbeatService runs per-connection (each env has its own heartbeat session)
- Reconnection logic runs independently per connection
- Unread counts, drafts, error banners scoped per environment

### UI
- Window header shows which environment it's connected to (ties into header-environment-indicator ticket)
- Settings shows connection status per environment (green/red dots)
- Switcher dots could be colored by environment

## What stays the same
- WebSocket protocol - unchanged
- Message format - unchanged
- Server configs, Keychain storage - already working
- Chat UI, tool rendering, markdown - unchanged

## Complexity
Medium-high. Biggest refactor is ConnectionManager from singleton to multi-instance, and threading that through the app.

---
meta:
  created: 2026-03-08
  status: next
  scope: ios, architecture
  icon: point.3.connected.trianglepath.dotted
