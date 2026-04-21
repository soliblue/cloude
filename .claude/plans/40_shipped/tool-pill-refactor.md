---
title: "Tool Pill Refactor"
description: "1,307 lines across 13 files for colored pills with an icon and a name. Cut hard."
created_at: 2026-04-07
tags: ["ui", "streaming"]
icon: wrench.and.screwdriver
build: 145
---


# Tool Pill Refactor
## Problem

### 1,307 lines for pills
The current tool pill system is 13 files / ~1,300 lines for something that fundamentally does: given a tool name and input, show a colored pill with an icon and a label. That's it.

### Data and view are fused
- `ToolCallLabel` is a SwiftUI View that doubles as a data model
- `ToolDetailSheet+Properties` creates throwaway `ToolCallLabel(name:input:)` just to access `.iconName`
- Truncation, icon resolution, and color mapping are instance methods on a View

### Duplication
- `chainedCommands` computed identically in `InlineToolPill` and `ToolDetailSheet+Properties`
- `iconName` resolved via throwaway ToolCallLabel in ToolDetailSheet

### Mixed paradigms
- Global free functions, static methods, instance methods, global dictionaries all doing the same kind of work with no consistency

### Unnecessary code
- 174 lines of bash icon dictionaries with 88+ command mappings
- 50+ line color map
- Per-command detail branches producing text too small to matter at pill size
- Verbose switch cases that could be simple lookups or eliminated entirely

## Current state: 13 files, ~1,307 lines

| File | Lines |
|------|-------|
| `ToolCallLabel.swift` | 157 |
| `ToolCallLabel+Display.swift` | 108 |
| `ToolCallLabel+BashIcons.swift` | 174 |
| `ToolCallLabel+Colors.swift` | 103 |
| `ToolCallLabel+Truncation.swift` | 43 |
| `StreamingMarkdownView+InlineToolPill.swift` | 139 |
| `StreamingMarkdownView+ToolGroup.swift` | 95 |
| `StreamingMarkdownParser+ToolCalls.swift` | 68 |
| `ToolDetailSheet.swift` | 99 |
| `ToolDetailSheet+Content.swift` | 143 |
| `ToolDetailSheet+Lists.swift` | 104 |
| `ToolDetailSheet+Properties.swift` | 74 |

## Goal

Drastically fewer lines. Every line must earn its place.

## Approach

### Extract `ToolMetadata` (pure Swift, no SwiftUI)
Single source of truth for `(name, input)` → `icon`, `color`, `displayName`, `detail`. Replaces all the scattered maps, global funcs, static methods, and instance-method lookups.

### Thin views
- `ToolCallLabel` becomes a tiny View consuming ToolMetadata
- `InlineToolPill` and `ToolDetailSheet` share data through ToolMetadata, zero duplication
- ToolDetailSheet extensions collapse where possible

### Aggressively trim
- Audit every bash command mapping: does the user actually see this at pill size?
- Kill detail branches that don't visually matter
- Remove truncation helpers that exist for edge cases nobody hits
- Consolidate icon/color maps into the simplest possible form
