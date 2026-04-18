---
title: "Android Tool Detail Diff View"
description: "Show unified diffs for Edit tool calls in the tool detail sheet."
created_at: 2026-04-02
tags: ["android", "tools", "ui"]
build: 125
icon: chevron.left.forwardslash.chevron.right
---
# Android Tool Detail Diff View {chevron.left.forwardslash.chevron.right}


## Context

iOS tool detail sheet renders Edit tool calls with a unified diff view: green lines for additions, red for deletions, gray hunk headers, syntax-highlighted content. Android currently shows raw input/output text for all tool types.

## Scope

- Detect `Edit` tool calls in ToolDetailSheet
- Parse `old_string` and `new_string` from input JSON
- Generate unified diff (or use the diff from output if available)
- Render with line-by-line coloring: green background for `+`, red for `-`, gray for `@@` headers
- Horizontal scroll for long lines
- Monospace font with line numbers

## Implementation

- Reuse diff rendering logic from GitScreen's diff viewer
- Extract shared `DiffView` composable usable in both git and tool detail contexts
