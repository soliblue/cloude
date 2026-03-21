# Tool Pill Compact Spacing {arrow.down.right.and.arrow.up.left}
<!-- priority: 10 -->
<!-- tags: tool-pill, ui -->
<!-- build: 64 -->

> Tightened tool pill internal padding and inter-pill spacing for a more compact layout.

## What
Tighten tool pill spacing now that borders are removed — less internal padding and less gap between pills.

## Changes
- `ChatView+ToolPill.swift`: Pill padding from 12h/6v to 10h/5v
- `ChatView+Components.swift`: Inter-pill spacing from 8 to 6
- `StreamingMarkdownView.swift`: Inter-pill spacing from 8 to 6
