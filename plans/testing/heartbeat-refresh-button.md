# Heartbeat Refresh Button

Add a refresh button to the heartbeat sheet toolbar so missed messages can be synced.

## Changes
- `HeartbeatSheet.swift`: Added `arrow.clockwise` button between the trigger button and interval picker
- Calls `syncHistory` with `Heartbeat.sessionId` and `connection.defaultWorkingDirectory`
- Shows spinner while refreshing (1s delay), same pattern as conversation refresh

## Status
- [x] Implemented
- [ ] Tested
