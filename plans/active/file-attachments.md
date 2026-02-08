# File Attachments {paperclip}
<!-- priority: 1 -->
<!-- tags: ui, input-bar, feature -->

> Send any file type (PDFs, text, code, etc.) from iPhone — not just images.

## Current State

Images flow: PhotosPicker → `AttachedImage(data, isScreenshot)` → base64 → WebSocket → Mac agent writes temp `.png` → prepends "read the image at /tmp/..." to prompt.

## Plan

Mirror the image flow but for arbitrary files. Minimal changes — reuse existing infrastructure.

### iOS App Changes

**1. New model: `AttachedFile`** (in `GlobalInputBar+Components.swift`)
```
struct AttachedFile: Identifiable {
    let id = UUID()
    let data: Data
    let filename: String    // "report.pdf"
    let mimeType: String?   // "application/pdf"
}
```

**2. Add `.fileImporter` to GlobalInputBar** (next to `.photosPicker`)
- New "File" button in the action menu (alongside Photo and Record)
- SF Symbol: `doc.fill`
- Allow any content type: `[.item]` (UTType)
- On pick: read file data, create `AttachedFile` with original filename
- Store in new `@Binding var attachedFiles: [AttachedFile]` on GlobalInputBar

**3. New `FileAttachmentStrip`** (in `GlobalInputBar+Components.swift`)
- Show below/alongside `ImageAttachmentStrip`
- Each pill: file icon + truncated filename + X button
- Use `doc.fill` icon with file extension label

**4. Encode files for transport** (new `FileEncoder` or extend `ImageEncoder`)
- Base64 encode file data
- Include filename metadata alongside

**5. Update `sendMessage()` in `MainChatView+Messaging.swift`**
- Encode attached files
- Pass to `connection.sendChat()` via new `filesBase64` parameter

### Shared (CloudeShared) Changes

**6. Add `filesBase64` + `fileNames` to `ClientMessage.chat`**
- New fields: `filesBase64: [String]?`, `fileNames: [String]?`
- Update encode/decode in `ClientMessage.swift`
- Add coding keys

### Mac Agent Changes

**7. Update `ClaudeCodeRunner.run()`**
- Accept `filesBase64: [String]?` and `fileNames: [String]?`
- Write temp files with original filenames (not `.png`)
- Prepend "First, read the file at /tmp/cloude_file_UUID_report.pdf" to prompt

**8. Update `AppDelegate+MessageHandling.swift`**
- Extract `filesBase64` and `fileNames` from chat message
- Pass through to runner

## Files
- `Cloude/Cloude/UI/GlobalInputBar.swift` (add file importer + menu button)
- `Cloude/Cloude/UI/GlobalInputBar+Components.swift` (AttachedFile model + FileAttachmentPill)
- `Cloude/Cloude/UI/MainChatView.swift` (add attachedFiles state)
- `Cloude/Cloude/UI/MainChatView+Messaging.swift` (encode + send files)
- `Cloude/CloudeShared/Sources/CloudeShared/Messages/ClientMessage.swift` (new fields)
- `Cloude Agent/Services/ClaudeCodeRunner.swift` (write temp files with names)
- `Cloude Agent/App/AppDelegate+MessageHandling.swift` (pass through files)
