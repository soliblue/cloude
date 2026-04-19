---
title: "Agent Tool Output as Markdown"
description: "Agent tool results in ToolDetailSheet now render via StreamingMarkdownView instead of monospaced Text."
created_at: 2026-03-18
tags: ["agent", "tool-pill", "markdown"]
icon: text.document
build: 86
---


# Agent Tool Output as Markdown
Agent tool results in ToolDetailSheet now render via `StreamingMarkdownView` instead of monospaced `Text`.

## Changes
- **`ToolDetailSheet.swift:106-107`** - Route Agent output to `markdownOutputSection`
- **`ToolDetailSheet+Content.swift:62-74`** - New `markdownOutputSection` using `StreamingMarkdownView`

**Files:** `ToolDetailSheet.swift`, `ToolDetailSheet+Content.swift`
