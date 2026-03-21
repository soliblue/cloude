# Tool Pill Reverse Order {arrow.uturn.backward}
<!-- priority: 10 -->
<!-- tags: tool-pill, ui -->
<!-- build: 70 -->

> Reversed tool pill order so the most recent tool call appears first (leftmost) in the horizontal scroll.

## What
Reversed tool pill order in message bubbles so the most recent tool call appears first (leftmost) in the horizontal scroll.

## Change
Added `.reversed()` to `ToolGroupView.toolHierarchy` — the `topLevel` array is now reversed before mapping to parent/children pairs.
