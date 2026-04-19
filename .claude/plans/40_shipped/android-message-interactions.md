---
title: "Android Message Interactions"
description: "Copy-to-clipboard, text selection, collapse/expand, and interrupted message indicator."
created_at: 2026-03-29
tags: ["android", "chat", "ux"]
icon: hand.tap
build: 120
---
# Android Message Interactions


## Desired Outcome
Match iOS message interaction features that are missing from Android.

## Sub-features

### 1. Copy to clipboard
- Long-press or tap menu on assistant messages to copy full text (preserving markdown)
- iOS uses `UIPasteboard` with both plain text and markdown representations
- Android: `ClipboardManager.setPrimaryClip()` with `ClipData.newPlainText()`

### 2. Text selection
- iOS allows selecting portions of user messages for copy
- Android: wrap user message text in `SelectionContainer` (Compose built-in)

### 3. Collapse/expand long responses
- `ChatMessage.isCollapsed` field already exists in Android model but has no UI
- iOS collapses messages over a threshold and shows "Show more" / "Show less" button
- Android: check text length, show truncated with `maxLines` + expand button, toggle `isCollapsed`

### 4. Interrupted message indicator
- `ChatMessage.wasInterrupted` field already exists in Android model but has no UI
- iOS shows visual indicator (different styling or label) when a message was interrupted
- Android: show "interrupted" label or dimmed styling in `MessageBubble`

## Implementation notes
All four sub-features are changes to `MessageBubble.kt` only. The data model already supports them.

**Files (iOS reference):** MessageBubble+TextSelection.swift, MessageBubble+Components.swift
**Files (Android):** MessageBubble.kt
