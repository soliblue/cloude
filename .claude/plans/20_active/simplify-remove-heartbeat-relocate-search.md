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
- `WindowManager.swift` - remove isHeartbeatShowing
- `ConnectionEvent.swift` - remove .heartbeatConfig and .heartbeatSkipped cases
- `EnvironmentConnection+Handlers.swift` - remove .getHeartbeatConfig send on auth
- `EnvironmentConnection+MessageHandler.swift` - remove .heartbeatConfig case

**Remove heartbeat from iOS UI:**
- `MainChatView.swift` - remove showIntervalPicker, heartbeatEnvironmentId, isHeartbeatActive, heartbeat window content tag(0), fix page indexing
- `MainChatView+Modifiers.swift` - remove HeartbeatIntervalModifier
- `MainChatView+PageIndicator.swift` - remove heartbeatIndicatorButton(), heartbeatIconName()
- `MainChatView+EventHandling.swift` - remove .heartbeatConfig case
- `MainChatView+Lifecycle.swift` - remove handleHeartbeatPageChange()
- `MainChatView+Messaging.swift` - remove heartbeat send/running checks
- `MainChatView+Messaging+Send.swift` - remove sendHeartbeatMessage()
- `CloudeApp+Toolbar.swift` - remove isHeartbeatShowing check

**Remove heartbeat from Mac agent:**
- `AppDelegate+MessageHandling.swift` - remove 4 heartbeat case handlers
- `Cloude_AgentApp.swift` - remove setupHeartbeat() call and function
- `Cloude_AgentApp+Services.swift` - remove heartbeat session check in onComplete

**Remove heartbeat from Linux relay:**
- `linux-relay/handlers.js` - remove heartbeat handlers

### Phase 2: Fix Page Indexing (Critical)

Currently heartbeat is page 0, windows are page 1+. After removal, windows become page 0+.

Every reference to `currentPageIndex` needs adjustment:
- Window index was `index + 1`, becomes just `index`
- `isHeartbeatActive` (page == 0) is removed entirely
- All page navigation logic shifts down by 1

### Phase 3: Search Relocation

- `MainChatView+PageIndicator.swift` - remove searchIndicatorButton() and its divider
- `ConversationView+EmptyState.swift` - add a search bar/button above recent chats that sets `showConversationSearch = true` (pass as callback from parent)
- Keep the search sheet itself unchanged (`MainChatView+SearchSheet.swift`)

### Phase 4: Page Indicator Cleanup

After removing heartbeat and search, the indicator just has window dots and the + button. Remove the two Dividers that surrounded heartbeat and search icons.

## Risks
- **Page index shift** is the riskiest part. Every `currentPageIndex` reference must be audited.
- Mac agent HeartbeatService removal may affect MemoryService (line 20 references HeartbeatService.shared.projectDirectory)
- Heartbeat conversation data in UserDefaults will be orphaned (harmless but could clean up)

## Files (complete list, ~30 files)
See Phase 1-4 above for the full breakdown.

## Codex Review

