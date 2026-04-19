---
title: "Text Selection & Partial Copy"
description: "Added long-press gesture on messages to open a selectable text sheet for partial copy."
created_at: 2026-03-01
tags: ["ui", "input"]
icon: text.cursor
build: 81
---


# Text Selection & Partial Copy
## Changes
1. Long press on any message (user or assistant) opens `TextSelectionSheet`
2. Sheet has selectable `UITextView` with link detection + copy-all button
3. Clear overlay on `Group` captures long press above `StreamingMarkdownView`
4. Removed inline `SelectableTextView` from user messages (caused scroll lock crashes)
5. `SelectableTextView` kept only for inline link/file pill rendering
