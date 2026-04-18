---
title: "File Attachment via Send Button"
description: "Attach files from iPhone (PDFs, documents, code, etc.) and send them to Claude with same UX as photo attachments."
created_at: 2026-02-08
tags: ["ui", "input"]
icon: paperclip
build: 67
---


# File Attachment via Send Button {paperclip}
## Changes
- **GlobalInputBar**: Added "File" option to send button menu, `.fileImporter` for document picker, `AttachedFile` model
- **GlobalInputBar+Components**: `FileAttachmentStrip` + `FileAttachmentPill` — cyan pills with filename + icon + remove button
- **ClientMessage**: Added `filesBase64: [AttachedFilePayload]?` to chat message (name + base64 data pairs)
- **ConnectionManager+API**: `sendChat` now accepts `filesBase64` parameter
- **MainChatView+Messaging**: Encodes attached files and sends alongside images
- **ClaudeCodeRunner**: Writes files to temp dir preserving original filenames, prepends "Read the file at" to prompt
- **RunnerManager**: Passes `filesBase64` through to runner
- Supports multiple file selection, any file type
