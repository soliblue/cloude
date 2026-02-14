# File Attachment via Send Button {paperclip}

> Attach files from iPhone (PDFs, documents, code, etc.) and send them to Claude — same UX as photo attachments

<!-- tags: ui, input -->

## Changes
- **GlobalInputBar**: Added "File" option to send button menu, `.fileImporter` for document picker, `AttachedFile` model
- **GlobalInputBar+Components**: `FileAttachmentStrip` + `FileAttachmentPill` — cyan pills with filename + icon + remove button
- **ClientMessage**: Added `filesBase64: [AttachedFilePayload]?` to chat message (name + base64 data pairs)
- **ConnectionManager+API**: `sendChat` now accepts `filesBase64` parameter
- **MainChatView+Messaging**: Encodes attached files and sends alongside images
- **ClaudeCodeRunner**: Writes files to temp dir preserving original filenames, prepends "Read the file at" to prompt
- **RunnerManager**: Passes `filesBase64` through to runner
- Supports multiple file selection, any file type
