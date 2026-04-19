---
title: "Code block toolbar always visible (no layout jump during streaming)"
description: "Removed isSingleLine condition that hid toolbar for single-line code blocks, preventing layout jumps mid-stream."
created_at: 2026-03-19
tags: ["ui", "markdown", "streaming"]
icon: rectangle.topthird.inset.filled
build: 96
---


# Code block toolbar always visible (no layout jump during streaming)
Removed the `isSingleLine` condition that hid the toolbar for single-line code blocks. Toolbar now always shows, preventing a layout jump mid-stream when a code block gains its second line.

## Desired Outcome
No more vertical shift in content below a code block during streaming.

**Files:** `Cloude/Cloude/UI/StreamingMarkdownView+Blocks.swift`
