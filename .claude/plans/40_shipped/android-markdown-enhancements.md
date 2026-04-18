---
title: "Android Markdown Enhancements"
description: "Add table rendering and code syntax highlighting to markdown."
created_at: 2026-03-29
tags: ["android", "markdown", "ui"]
build: 120
icon: text.badge.checkmark
---
# Android Markdown Enhancements {text.badge.checkmark}


## Desired Outcome
Bring Android markdown rendering to full parity with iOS.

## Sub-features

### 1. Table rendering
- iOS `StreamingMarkdownView+Table.swift` renders tables with column headers, alignment, borders
- Android `MarkdownText.kt` currently parses tables but rendering may be basic
- Need: proper table layout with header row styling, cell borders, horizontal scroll for wide tables
- Use `Row`/`Column` composables or `LazyRow` for wide tables

### 2. Code syntax highlighting
- iOS `StreamingMarkdownView+SyntaxHighlighter.swift` highlights 15+ languages (Swift, JavaScript, Python, Go, Rust, bash, etc.)
- Android code blocks currently show monospace text without color
- Need: regex-based token highlighting for keywords, strings, comments, numbers
- Language detection from code fence (```swift, ```python, etc.)
- Consider: `compose-richtext` library or custom regex highlighter
- Colors should match theme (use `MaterialTheme.colorScheme` variants)

### 3. Horizontal rules
- iOS renders `---` / `***` as styled dividers
- Android: `HorizontalDivider()` composable

## Implementation notes
All changes in `MarkdownText.kt`. Syntax highlighting is the heaviest lift - consider a simple keyword-based approach first, expand language support incrementally.

**Files (iOS reference):** StreamingMarkdownView+SyntaxHighlighter.swift, StreamingMarkdownView+Table.swift, StreamingMarkdownView+Blocks.swift
**Files (Android):** MarkdownText.kt
