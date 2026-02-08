# Heartbeat Header Unification {rectangle.grid.1x2}

> Reuse the normal window header layout for heartbeat instead of custom UI — title pill, refresh button, interval picker.

## Problem
The heartbeat window has a completely custom header with a dedicated trigger button, but this is redundant — users can already send messages to the heartbeat conversation normally. The heartbeat should feel like a regular window, not a special-case UI.

## Idea
Reuse the normal `windowHeader` layout for the heartbeat window:
- **Left side**: Same title pill (ConversationInfoLabel) showing name, symbol, cost — but **not tappable** (no window edit sheet, since heartbeat isn't a switchable conversation)
- **Right side**: Replace the close/dismiss button with the **interval picker** (scheduling controls)
- **Remove** the dedicated bolt.heart trigger button — just type and send like any other conversation
- Keep the refresh button (arrow.clockwise) in the same position as normal windows

## Benefits
- Less custom code to maintain
- Heartbeat feels like a first-class window, not a separate UI
- Users already know how to interact with normal windows
- The trigger button was always redundant with just sending a message

## Open Questions
- Should the title pill show "Heartbeat" or the working directory like normal windows?
- Do we lose anything by removing the one-tap trigger? (Maybe keep it in the page indicator heart button only?)
- Should long-press on the title pill open scheduling instead of window edit?
