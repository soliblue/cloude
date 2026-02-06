# Split ChatView+MessageBubble.swift

## Changes
505 lines → 2 files:
- `ChatView+MessageBubble.swift` (200 lines) - message bubbles
- `ChatView+ToolPill.swift` (272 lines) - inline tool pills + shimmer

## Test
- Tool pills render inline in messages
- Shimmer animation on executing tools
- Tap pill → quick action (file open, memory)
- Long press pill → detail sheet
- Chained command pills display correctly
- Task tool children expand/collapse
