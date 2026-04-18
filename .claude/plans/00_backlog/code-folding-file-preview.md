---
title: "Code Folding in File Preview"
description: "Collapse deeply nested code blocks in file preview so large files are easier to scan."
created_at: 2026-03-03
tags: ["files", "ui"]
icon: chevron.down.square
build: 82
---


# Code Folding in File Preview {chevron.down.square}
Auto-collapse leaf nodes in code files viewed in FilePreviewView. Show high-level structure first — functions visible, innermost blocks (if/else inside loops inside functions) collapsed.

## Key Insight
We already do collapsible sections in StreamingMarkdownView with HeaderSectionView. Same pattern applies here — indentation-based instead of header-based. Medium effort, not hard.

## Approach Ideas
- Parse indentation/braces to determine nesting depth (same concept as markdown header levels)
- Identify leaf blocks (deepest nested) and collapse them by default
- Reuse the collapsible pattern from StreamingMarkdownView's HeaderSectionView
- Replace single `Text(highlighted)` in `sourceTextView` with line-by-line collapsible block rendering
- Tap collapsed region to expand

## Files
- `FilePreviewView+Content.swift` — `sourceTextView` is where code renders today (single `Text(highlighted)`)
- `StreamingMarkdownView.swift` — `HeaderSectionView` is the existing collapsible pattern to follow
