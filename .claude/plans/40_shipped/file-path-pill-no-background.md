---
title: "File Path Pill: Remove Background Color"
description: "Removed background color from file path pills so they blend with surrounding text."
created_at: 2026-03-15
tags: ["ui", "markdown"]
icon: textformat
build: 86
---


# File Path Pill: Remove Background Color
File path references in messages had a colored background that made them visually larger than surrounding text. Removed the background - now just uses colored font, matching the subtlety of inline code.

## Changes
- `StreamingMarkdownView+InlineText.swift`: Removed `attr.backgroundColor` line from `.filePath` case

## Test
- Send a message that generates file path references
- Verify file pills have colored text but no background color
- Should blend better with surrounding text
