---
title: "Inline Code: Remove Background Color"
description: "Removed background color from inline code rendering, keeping only monospaced font."
created_at: 2026-03-15
tags: ["ui", "markdown"]
icon: chevron.left.forwardslash.chevron.right
build: 86
---


# Inline Code: Remove Background Color
**Files:** `StreamingMarkdownView+InlineText.swift`

## Test
- Send a message with inline code (backticks) and verify no background color appears
- Inline code should still be monospaced font
