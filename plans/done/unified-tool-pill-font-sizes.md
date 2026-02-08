# Unified Tool Pill Font Sizes
<!-- priority: 10 -->
<!-- tags: tools, ui -->
<!-- build: 56 -->

## Problem
Tool pills had inconsistent font sizes — `.regular` (11pt text, 13pt icon) vs `.small` (10pt text, 12pt icon) used in different contexts, plus chained command pills had their own hardcoded sizes.

## Changes

### ChatView+ToolCalls.swift
- Removed `Size` enum (`.regular`/`.small`)
- Unified to single size: 11pt text, 12pt icon
- Weight differences preserved (semibold names, regular details)

### ChatView+ToolPill.swift
- Removed `size: .small` from `ToolCallLabel` usage
- Chained command text: 10pt → 11pt
- Chained separator `›`: 12pt → 11pt
- Overflow `+N` count: 10pt → 11pt

### ToolDetailSheet.swift
- Removed `size: .small` from child tool call labels
