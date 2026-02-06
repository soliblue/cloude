# Queued Send Indicator

Send button visually signals when a message will be queued instead of sent immediately.

## Implementation

When `isRunning && canSend`, the send button changes:
- Icon: `paperplane.fill` → `paperplane.circle.fill` (slightly larger, 26pt vs 22pt)
- Color: `.accentColor` (blue) → `.orange`
- Animated transition (0.2s ease-in-out)

Reverts to normal blue paperplane when streaming stops.

## Files
- `Cloude/Cloude/UI/GlobalInputBar.swift` — added `willQueue` computed property, conditional icon/color

## Test
- Type while Claude is streaming — button should be orange `paperplane.circle.fill`
- When streaming stops, button animates back to blue `paperplane.fill`
- Empty input while streaming should still show disabled blue (not orange)
