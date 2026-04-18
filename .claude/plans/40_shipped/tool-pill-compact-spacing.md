---
title: "Tool Pill Compact Spacing"
description: "Tightened tool pill internal padding and inter-pill spacing for a more compact layout."
created_at: 2026-02-08
tags: ["tool-pill", "ui"]
icon: arrow.down.right.and.arrow.up.left
build: 63
---


# Tool Pill Compact Spacing {arrow.down.right.and.arrow.up.left}
## What
Tighten tool pill spacing now that borders are removed — less internal padding and less gap between pills.

## Changes
- `ChatView+ToolPill.swift`: Pill padding from 12h/6v to 10h/5v
- `ChatView+Components.swift`: Inter-pill spacing from 8 to 6
- `StreamingMarkdownView.swift`: Inter-pill spacing from 8 to 6
