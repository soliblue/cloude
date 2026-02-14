# Tool Pill Reverse Order
<!-- build: 70 -->

**Status**: testing
**Changed**: StreamingMarkdownView.swift

## What
Reversed tool pill order in message bubbles so the most recent tool call appears first (leftmost) in the horizontal scroll.

## Change
Added `.reversed()` to `ToolGroupView.toolHierarchy` — the `topLevel` array is now reversed before mapping to parent/children pairs.
