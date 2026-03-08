# Multi-Environment Parallel Connections

Connect to multiple environments simultaneously and stream responses in parallel across conversations.

## Why
Currently only one environment is active at a time. Switching environments disconnects from the previous one, blocking work on conversations from other envs. With multiple machines (Mac + Linux server + future cloud instances), parallel connections would let all conversations stay live.

## Changes

### ConnectionManager per environment
- Replace single global ConnectionManager with a pool - one WebSocket connection per environment
- EnvironmentStore manages the pool, each ServerEnvironment gets its own connection lifecycle
- Conversations route messages to their environment's connection (via environmentId from environment-chat-ownership)

### Parallel streaming
- Multiple conversations can stream responses simultaneously from different environments
- UI already supports multiple windows - each window's conversation streams from its own environment's connection
- RunningConversationId becomes per-connection, not global

### Auth and reconnection
- Each connection handles its own auth handshake and reconnection logic
- HeartbeatService runs per-connection (each environment has its own heartbeat session)

### UI considerations
- Settings shows connection status per environment (green/red dots)
- Window header could show which environment it's connected to
- Switcher dots could be colored by environment

## Complexity
High - requires significant refactor of ConnectionManager (currently singleton with single connection state). Depends on environment-chat-ownership being done first.

---
meta:
  created: 2026-03-08
  status: backlog
  scope: ios, architecture
  icon: point.3.connected.trianglepath.dotted
