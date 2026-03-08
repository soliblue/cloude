# Custom Context Menu (No Zoom)

## Problem
- iOS `.contextMenu` causes a zoom-out/shrink preview animation on long-press
- This conflicts with chart widget drag gestures inside message bubbles
- The zoom effect feels disruptive for a chat app

## Solution
- Replace `.contextMenu` on MessageBubble with a custom long-press overlay
- Use `LongPressGesture` + custom popover/overlay with menu items
- Skip long-press menu entirely on bubbles containing interactive widgets
- Keep same menu items: Copy, Select Text, Collapse, TTS

## Files
- `Cloude/Cloude/UI/MessageBubble.swift` — replace `.contextMenu` with custom gesture + overlay
