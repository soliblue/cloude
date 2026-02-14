# Heartbeat Slash Icon When Not Scheduled
<!-- priority: 10 -->
<!-- tags: heartbeat -->
<!-- build: 56 -->

## Summary
Show a slash through the heart icon in the window switcher when heartbeat is not scheduled.

## Changes
- **File**: `Cloude/Cloude/UI/MainChatView+PageIndicator.swift`
- Added `isScheduled` check based on `heartbeatConfig.intervalMinutes != nil`
- Added `heartbeatIconName(active:scheduled:)` helper
- Icon states:
  - Scheduled + active: `heart.circle.fill` (accent)
  - Scheduled + inactive: `heart.fill` (accent)
  - Not scheduled + active: `heart.slash.fill` (accent)
  - Not scheduled + inactive: `heart.slash` (secondary/gray)

## Testing
- [ ] Verify heart.slash appears when heartbeat interval is Off
- [ ] Verify heart.fill appears when heartbeat interval is set
- [ ] Verify active states (circle.fill / slash.fill) when on heartbeat page
- [ ] Verify color is gray when not scheduled + not active
