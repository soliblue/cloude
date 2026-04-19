---
title: "Simplify: Remove Heartbeat & Relocate Search"
description: "Remove the heartbeat feature entirely and move search to the empty chat state."
created_at: 2026-03-24
tags: ["agent", "ui", "cleanup"]
icon: minus.circle
build: 103
---


# Simplify: Remove Heartbeat & Relocate Search
## What
1. Remove the entire heartbeat feature (iOS app, Mac agent, shared messages, Linux relay)
2. Remove the search magnifying glass icon from the bottom page indicator bar
3. Add a search bar to the empty chat view (above recent chats) that opens the existing search sheet
4. Clean up the page indicator to just show window dots (no heartbeat icon, no search icon, no dividers)

## Why
Heartbeat is unused complexity. Search icon in the bottom bar is redundant if search lives in empty state. Simplifying the nav reduces cognitive load.

## Implementation

### Phase 1: Heartbeat Removal

**Delete entire files:**
- `Cloude/Cloude/UI/MainChatView+Heartbeat.swift`
- `Cloude/Cloude/UI/MainChatView+HeartbeatChat.swift`
- `Cloude/Cloude Agent/Services/HeartbeatService.swift`

**Remove heartbeat from shared messages:**
- `CloudeShared/.../ServerMessage.swift` - remove `.heartbeatConfig` case
- `CloudeShared/.../ServerMessage+Encoding.swift` - remove encoding
- `CloudeShared/.../ServerMessage+Decoding.swift` - remove decoding
- `CloudeShared/.../ClientMessage.swift` - remove 4 heartbeat cases
- `CloudeShared/.../ClientMessage+Encoding.swift` - remove encoding
- `CloudeShared/.../ClientMessage+Decoding.swift` - remove decoding
- `CloudeShared/.../CloudeShared.swift` - remove `Heartbeat` enum

**Remove heartbeat from iOS models/services:**
- `ConversationStore.swift` - remove HeartbeatConfig struct, heartbeatConfig property, heartbeatConversation, isHeartbeat(), related methods
- `ConversationStore+Persistence.swift` - remove heartbeat conversation creation and UserDefaults loading
- `ConversationStore+Messaging.swift` - remove Heartbeat special-case in queued-message replay (line 94)
- `WindowManager.swift` - remove isHeartbeatShowing
- `ConnectionEvent.swift` - remove .heartbeatConfig and .heartbeatSkipped cases
- `EnvironmentConnection+Handlers.swift` - remove .getHeartbeatConfig send on auth
- `EnvironmentConnection+MessageHandler.swift` - remove .heartbeatConfig case
- `EnvironmentConnection+IOSTools.swift` - remove .heartbeatSkipped emission (line 43)

**Remove heartbeat from iOS UI:**
- `MainChatView.swift` - remove showIntervalPicker, heartbeatEnvironmentId, isHeartbeatActive, heartbeat window content tag(0), fix page indexing
- `MainChatView+Modifiers.swift` - remove HeartbeatIntervalModifier
- `MainChatView+PageIndicator.swift` - remove heartbeatIndicatorButton(), heartbeatIconName()
- `MainChatView+EventHandling.swift` - remove .heartbeatConfig case
- `MainChatView+Lifecycle.swift` - remove handleHeartbeatPageChange(), audit "page 0 is special" guards
- `MainChatView+Messaging.swift` - remove heartbeat send/running checks
- `MainChatView+Messaging+Send.swift` - remove sendHeartbeatMessage()
- `CloudeApp+Toolbar.swift` - remove isHeartbeatShowing check

**Remove heartbeat from Mac agent:**
- `AppDelegate+MessageHandling.swift` - remove 4 heartbeat case handlers, keep projectDirectory assignment
- `Cloude_AgentApp.swift` - remove setupHeartbeat() call and function
- `Cloude_AgentApp+Services.swift` - remove heartbeat session check in onComplete
- `MemoryService.swift` - replace HeartbeatService.shared.projectDirectory with alternative (use AppDelegate's stored projectDirectory directly)

**Remove heartbeat from Linux relay:**
- `linux-relay/handlers.js` - remove heartbeat handlers

**Update documentation:**
- `CLAUDE.md` - remove Heartbeat section (line 26) and heartbeat session ID note (line 154)
- `README.md` - remove heartbeat feature row (line 155)
- `.claude/skills/system/skill.md` - remove heartbeat reference (line 28)
- `.claude/skills/weather/skill.md` - remove heartbeat reference (line 25)

### Phase 2: Fix Page Indexing (Critical)

Currently heartbeat is page 0, windows are page 1+. After removal, windows become page 0+.

Every reference to `currentPageIndex` needs adjustment:
- Window index was `index + 1`, becomes just `index`
- `isHeartbeatActive` (page == 0) is removed entirely
- All page navigation logic shifts down by 1
- Audit ALL "page 0 is special" branches in MainChatView.swift and MainChatView+Lifecycle.swift

### Phase 3: Search Relocation

- `MainChatView+PageIndicator.swift` - remove searchIndicatorButton() and its divider
- `ConversationView+EmptyState.swift` - add a search bar/button above recent chats that sets `showConversationSearch = true` (pass as callback from parent)
- `ConversationView+Components.swift` - wire the callback through
- `ConversationView.swift` / `MainChatView+Windows.swift` - wire callback from parent
- Keep the search sheet itself unchanged (`MainChatView+SearchSheet.swift`)

### Phase 4: Page Indicator Cleanup

After removing heartbeat and search, the indicator just has window dots and the + button. Remove the two Dividers that surrounded heartbeat and search icons.

## Risks
- **Page index shift** is the riskiest part. Every `currentPageIndex` reference must be audited.
- Mac agent MemoryService depends on HeartbeatService.shared.projectDirectory - need replacement owner
- Heartbeat conversation JSON on disk will remain as a normal conversation (acceptable)
