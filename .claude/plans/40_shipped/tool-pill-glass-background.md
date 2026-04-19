---
title: "Tool Pill Glass Background"
description: "Add a liquid glass background to tool pills for a more polished, native iOS feel."
created_at: 2026-02-08
tags: ["ui", "tool-pills"]
icon: pill.circle.fill
build: 64
---


# Tool Pill Glass Background
## Problem

Tool pills currently have no background fill — they float as plain text with an icon. Adding a subtle glass material background would make them feel more like native UI elements and improve visual hierarchy in the chat feed.

## Approach

- Apply `.glassEffect` or `.ultraThinMaterial` background to `InlineToolPill`
- Keep the existing colored left-edge icon
- Ensure it looks good in both light and dark mode
- Test with collapsed and expanded states

## Files
- `Cloude/Cloude/UI/ChatView+ToolPill.swift`
