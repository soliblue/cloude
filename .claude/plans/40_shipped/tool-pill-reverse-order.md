---
title: "Tool Pill Reverse Order"
description: "Reversed tool pill order so the most recent tool call appears first (leftmost) in the horizontal scroll."
created_at: 2026-02-10
tags: ["tool-pill", "ui"]
icon: arrow.uturn.backward
build: 70
---


# Tool Pill Reverse Order {arrow.uturn.backward}
## What
Reversed tool pill order in message bubbles so the most recent tool call appears first (leftmost) in the horizontal scroll.

## Change
Added `.reversed()` to `ToolGroupView.toolHierarchy` — the `topLevel` array is now reversed before mapping to parent/children pairs.
