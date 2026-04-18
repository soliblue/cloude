---
title: "Tool Pill Border Style"
description: "Changed tool pills from colored background fill to colored border outline for a subtler look."
created_at: 2026-02-08
tags: ["tool-pill", "ui"]
icon: circle.dashed
build: 61
---


# Tool Pill Border Style {circle.dashed}
## Summary
Changed tool pills from colored background fill to colored border outline for a more subtle, cleaner look.

## Changes
- `ChatView+ToolPill.swift`: Replaced `.background(color.opacity(0.12))` with a light system background + colored `strokeBorder` at 0.35 opacity, 1.5pt width

## Testing
- [ ] Tool pills render with colored border instead of colored fill
- [ ] Different tool types show correct border colors (Read=blue, Write=orange, Bash=green, etc.)
- [ ] Shimmer animation still works on executing pills
- [ ] Pills look good in both light and dark mode
- [ ] Chained bash command pills look correct
- [ ] Child count badge still visible
