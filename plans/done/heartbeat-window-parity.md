# Heartbeat Window Feature Parity

## Problem
The heartbeat window (page 0 in MainChatView) is missing features that normal chat windows have. It feels like a second-class citizen compared to regular windows.

## Current State

**Normal windows have** (`windowHeader` in MainChatView.swift:285):
- Title pill (ConversationInfoLabel) — shows name, symbol, cost
- Refresh button (arrow.clockwise) — syncs history from CLI
- Close button (xmark)

**Heartbeat window has** (`heartbeatHeader` in MainChatView+Heartbeat.swift:23):
- Trigger button (bolt.heart.fill)
- Status text ("Running..." or last triggered time)
- Interval picker button
- **No refresh button**

## Changes

### 1. Add Refresh Button
Add `arrow.clockwise` to the heartbeat header, matching normal windows. Calls `connection.syncHistory(sessionId: Heartbeat.sessionId, workingDirectory:)` to re-fetch conversation history from the CLI.

### 2. Show Conversation Name/Symbol if Set
The heartbeat can receive a name via `cloude rename` during execution. Currently the header always shows "Heartbeat" — it should show the conversation's custom name/symbol if one has been set (falling back to "Heartbeat" with heart icon).

## Files to Change
- `Cloude/Cloude/UI/MainChatView+Heartbeat.swift` — add refresh button, show dynamic name

## Notes
- The HeartbeatSheet (full-screen modal) already has a refresh button — this is about the inline header in the main pager view
- Keep the heartbeat trigger button and interval picker — just add refresh alongside them
