---
title: "Parallel Environment Connections"
description: "Enabled simultaneous connections to all environments for parallel streaming."
created_at: 2026-03-09
tags: ["connection", "env"]
icon: point.3.connected.trianglepath.dotted
build: 82
---


# Parallel Environment Connections {point.3.connected.trianglepath.dotted}
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

## Progress

### Done
- **EnvironmentConnection class created** - extracted per-connection state and logic into `EnvironmentConnection` (5 new files):
  - `EnvironmentConnection.swift` - core class with WebSocket, auth, reconnection, per-env state (isConnected, isAuthenticated, isTranscribing, agentState, skills, processes, git status queue, file cache)
  - `EnvironmentConnection+Handlers.swift` - connection lifecycle handlers
  - `EnvironmentConnection+MessageHandler.swift` - message parsing and dispatch
  - `EnvironmentConnection+FileHandlers.swift` - file operation routing
  - `EnvironmentConnection+CommandHandlers.swift` - command handling
- **ConnectionManager refactored to connection pool** - `connections: [UUID: EnvironmentConnection]` replaces single connection. Routing helpers: `connection(for:)`, `connectionForConversation(_:)`, `anyAuthenticatedConnection()`
- **ConnectionManager slimmed down** - net -424 lines, handler logic moved into EnvironmentConnection. CM now orchestrates rather than implements.
- **Conversation-to-environment routing** - `conversationEnvironments: [UUID: UUID]` maps each conversation to its environment
- **Aggregated state** - `isAuthenticated` true if any connection is authenticated
- **Event bus** - `PassthroughSubject<ConnectionEvent, Never>` for EnvironmentConnection to communicate back to UI
- **UI adapted** - MainChatView, SettingsView+Environments, WindowEditSheet+Form, FilePreviewView, FolderPickerView updated for multi-connection model
- **CloudeApp updated** - app entry point wired to new connection pool

- **Message routing fixed** - all sendChat, transcribe, /usage, question answers, queued message replay pass environmentId explicitly
- **Settings cleaned up** - removed Usage, Memories, Plans (accessible from chat with proper env context)
- **Auto-connect removed** - no more auto-connect on launch, power button is explicit toggle, no retry loops
- **Per-env state already working** - unread counts (per-window), error banners (per-EnvironmentConnection lastError), settings status dots (green/yellow/gray per env card)

### Remaining
- Switcher dots colored by environment (cosmetic, nice-to-have)
- Build and test with multiple simultaneous connections

---
meta:
  created: 2026-03-08
  status: active
  scope: ios, architecture
  icon: point.3.connected.trianglepath.dotted
