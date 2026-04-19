---
title: "Fix Streaming Markdown Layout Jump"
description: "Fixed three streaming markdown layout jump issues across block spacing, animation, and paragraph splitting."
created_at: 2026-03-19
tags: ["streaming", "markdown"]
icon: text.justify.leading
build: 103
---


# Fix Streaming Markdown Layout Jump
Three fixes across two builds for streaming markdown layout jumps:

**Fix 1** (build 99): Removed `.animation(.easeOut(duration: 0.6), value: text)` from the `StreamingMarkdownView` VStack. The FPS isolation fix made this animation play through fully, causing content to slide up when new blocks appeared.

**Fix 2** (build 99): `VStack(spacing: 8)` → `VStack(spacing: 0)` + `.padding(.bottom, 8)` per block. Space is now part of each block from the start, not materializing between blocks on completion.

**Fix 3** (build 100): Root cause fix. `stableSplitPoint` was returning nil when text ended with `\n\n` (paragraph just completed), causing stale `frozenBlocks` + full-text reparse as tail, merging paragraphs into one block with a `\n\n` inside rendering as a visible blank line gap. Fixed by tracking the last blank with non-blank content after it (not trailing blanks). Also clear `frozenBlocks` in the nil fallback, and `parseTextBlock` now breaks on blank lines so paragraphs are always separate blocks.

**Files:** `Cloude/Cloude/UI/StreamingMarkdownView.swift`, `Cloude/Cloude/UI/StreamingMarkdownParser.swift`
