# Tool Pill Compact Spacing
<!-- build: 64 -->

**Status:** testing
**Tags:** ui, chat

## What
Tighten tool pill spacing now that borders are removed — less internal padding and less gap between pills.

## Changes
- `ChatView+ToolPill.swift`: Pill padding from 12h/6v to 10h/5v
- `ChatView+Components.swift`: Inter-pill spacing from 8 to 6
- `StreamingMarkdownView.swift`: Inter-pill spacing from 8 to 6
