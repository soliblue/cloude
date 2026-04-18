---
title: "Android File Attachments"
description: "Attach files from device to chat messages."
created_at: 2026-03-29
tags: ["android", "input"]
icon: paperclip
build: 120
---
# Android File Attachments {paperclip}

## Implementation

- `InputBar.kt` - paperclip button opens `OpenMultipleDocuments("*/*")` file picker, attached files shown as pills with document icon + filename + remove button
- `ChatViewModel.kt` - `sendMessage()` accepts `filesBase64: List<AttachedFilePayload>?`, passes to `ClientMessage.Chat`
- `ChatScreen.kt` - passes `onSend` lambda with images and files to InputBar
- `MessageBubble.kt` - shows file count indicator on user messages via `fileCount` field
- `Conversation.kt` - `ChatMessage` has `fileCount: Int = 0` to track attachments in bubble display

Wire protocol already had `AttachedFilePayload(name, data)` and `filesBase64` in `ClientMessage.Chat` from SharedTypes.

**Files (iOS reference):** GlobalInputBar+FileAttachments.swift
**Files (Android):** InputBar.kt, ChatViewModel.kt, ChatScreen.kt, MessageBubble.kt, Conversation.kt
