# Fix: Scroll to empty screen during streaming {arrow.down}
<!-- priority: 10 -->
<!-- tags: ui, streaming -->
<!-- build: 71 -->

> Fixed scroll jumping to empty space after sending a message by scrolling to bottom instead of top-anchoring.

## Problem
When sending a message, the scroll would jump to the user message with `.top` anchor, positioning it at the top of the screen with empty space below. If the assistant response hadn't started yet, the user would see a blank screen and have to tap scroll-to-bottom to see content.

## Fix
Changed the user-message scroll behavior from anchoring the user message at the top of the viewport (`scrollToMessage(id, anchor: .top)`) to scrolling to the bottom of the conversation (`proxy.scrollTo(bottomId, anchor: .bottom)`). This keeps content visible and avoids the empty screen gap.

## File changed
- `Cloude/Cloude/UI/ConversationView+Components.swift` — `.onChange(of: userMessageCount)` handler
