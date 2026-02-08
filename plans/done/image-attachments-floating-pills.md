# Floating Image Attachment Pills
<!-- priority: 10 -->
<!-- tags: heartbeat, input, tools, ui -->
<!-- build: 56 -->

## Problem
When attaching an image, it currently renders as a 36x36 thumbnail **inside** the text field area (GlobalInputBar.swift:162-176), shrinking the available typing space. Only one image can be attached at a time (`selectedImageData: Data?` is singular). Screenshots require an extra tap on the banner to attach — they should auto-attach.

## Goal
- Images appear as **floating pills above the input bar**, same layer as slash command suggestions and file suggestions
- Support **multiple image attachments** per message
- Image pills are dismissible (X button) and visually consistent with existing pill patterns
- Screenshots auto-attach as a pill (with a distinct icon), replacing the current banner flow
- Screenshot pills are visually distinct (e.g. `camera.viewfinder` icon badge) but same pill design as manual photos

## Current Architecture

| Component | File | Details |
|-----------|------|---------|
| Photo picker state | GlobalInputBar.swift:26-27 | `selectedItem`, `showPhotoPicker` |
| Inline image preview | GlobalInputBar.swift:162-176 | 36x36 thumbnail inside text field HStack |
| Image data state | MainChatView.swift:17 | `selectedImageData: Data?` |
| Screenshot state | MainChatView.swift:24-25 | `screenshotData: Data?`, `screenshotDismissTask` |
| Screenshot banner | GlobalInputBar.swift:112-119 | `ScreenshotBanner` shown above input |
| Screenshot detection | MainChatView.swift:206-208 | `userDidTakeScreenshotNotification` listener |
| Screenshot fetch | MainChatView+Utilities.swift:102-146 | `fetchLatestScreenshot()`, `loadLatestPhoto()` |
| Screenshot attach/dismiss | MainChatView+Utilities.swift:148-161 | Sets `selectedImageData`, clears banner |
| ScreenshotBanner component | GlobalInputBar+Components.swift:4-39 | Thumbnail + attach/dismiss buttons |
| Draft persistence | MainChatView.swift:138-153 | Saves `(text, imageData)` per window |
| Send logic | MainChatView+Messaging.swift:7-31 | Base64 encoding, thumbnail creation |
| Message model | Conversation.swift:131 | `imageBase64: String?` on ChatMessage |
| Message display | ChatView+MessageBubble.swift:68-79 | Thumbnail in bubble |

## Changes

### 1. State: Singular → Array (with source tracking)

**New struct** (in GlobalInputBar+Components.swift or similar):
```swift
struct AttachedImage: Identifiable {
    let id = UUID()
    let data: Data
    let isScreenshot: Bool
}
```

**MainChatView.swift**
- `@State var selectedImageData: Data?` → `@State var attachedImages: [AttachedImage]`
- Remove `screenshotData: Data?` and `screenshotDismissTask` — screenshots now auto-attach directly
- Draft persistence: `drafts: [UUID: (text: String, images: [AttachedImage])]`

**GlobalInputBar.swift**
- `@Binding var selectedImageData: Data?` → `@Binding var attachedImages: [AttachedImage]`
- Remove `screenshotData` binding and `onAttachScreenshot`/`onDismissScreenshot` callbacks
- Photo picker `.onChange` appends `AttachedImage(data:, isScreenshot: false)` to array

### 2. Screenshots: Banner → Auto-Attach

**MainChatView+Utilities.swift**
- `fetchLatestScreenshot()` / `loadLatestPhoto()`: instead of setting `screenshotData` (which shows the banner), directly append to `attachedImages` as `AttachedImage(data:, isScreenshot: true)`
- Remove `attachScreenshot()`, `dismissScreenshot()`, `screenshotDismissTask` logic
- No more 5-second auto-dismiss timer — the screenshot just appears as a removable pill

**GlobalInputBar.swift**
- Remove the `ScreenshotBanner` conditional block (lines 112-119)
- Screenshots now appear in the same `ImageAttachmentStrip` as manual photos

**GlobalInputBar+Components.swift**
- Remove or repurpose `ScreenshotBanner` struct (no longer needed)

### 3. UI: Inline Thumbnail → Floating Pills Above Input Bar

**GlobalInputBar.swift**
- Remove the inline image preview block (lines 162-176)
- Add `ImageAttachmentStrip` in the VStack, right before the ZStack (closest to input field):

```
VStack(spacing: 0)
  ├─ Pending Audio Banner
  ├─ File Suggestions
  ├─ Slash Command Suggestions
  ├─ Image Attachment Strip ← NEW (only when images attached)
  └─ ZStack (text field, buttons, recording overlay)
```

**GlobalInputBar+Components.swift** (new components):

`ImageAttachmentStrip`:
- Horizontal `ScrollView` of `ImageAttachmentPill` views
- Same padding/spacing pattern as `SlashCommandSuggestions`
- Transition: `.move(edge: .bottom).combined(with: .opacity)`

`ImageAttachmentPill`:
- 44x44 rounded rect image thumbnail
- X dismiss button overlay (top-trailing, `xmark.circle.fill`)
- If `isScreenshot`: small badge icon overlay (bottom-leading, e.g. `camera.viewfinder` in a tiny circle) to differentiate from manual photos
- `onRemove: () -> Void` callback

### 4. Send Logic: Single → Multiple Images ✅ FIXED

**BUG FOUND & FIXED**: Only the first image was being sent to the Mac agent. The full pipeline now supports multiple images:

**ClientMessage.swift (CloudeShared)**
- `imageBase64: String?` → `imagesBase64: [String]?` in the `.chat` case
- Decode supports both old `imageBase64` (single) and new `imagesBase64` (array) for backward compat
- Encode uses `imagesBase64` array

**ConnectionManager+API.swift**
- `sendChat()` parameter: `imageBase64: String?` → `imagesBase64: [String]?`

**MainChatView+Messaging.swift**
- `sendMessage()`: sends ALL images as `allImagesBase64: [String]?`, not just `.first`
- Creates thumbnails for all images, stores in ChatMessage for UI display
- Both `sendHeartbeatMessage` and `sendConversationMessage` updated

**HeartbeatSheet.swift**
- Same fix applied — sends all images, not just first

**CloudeApp.swift (screenshot handler)**
- Updated to use `imagesBase64: [base64]` (wraps single screenshot in array)

**RunnerManager.swift + AppDelegate+MessageHandling.swift**
- Parameter renamed: `imageBase64:` → `imagesBase64:`

**ClaudeCodeRunner.swift**
- `tempImagePath: String?` → `tempImagePaths: [String]` (array)
- Writes ALL images as temp files, prepends multiple "read the image at" lines to prompt
- Cleanup iterates over all temp paths

**HeartbeatService.swift**
- Updated to pass `imagesBase64: nil` instead of `imageBase64: nil`

**Conversation.swift**
- No changes needed — `imageBase64: String?` (thumbnail for single display) and `imageThumbnails: [String]?` (all thumbnails) already correct

### 5. Message Bubble Display

**ChatView+MessageBubble.swift**
- If `imageThumbnails` has multiple entries, show horizontal row of 36x36 thumbnails
- Single image: same as current behavior
- Keep 36x36 per thumbnail

### 6. Cleanup: `canSend` and Swipe-to-Clear

**GlobalInputBar.swift**
- `canSend`: `!inputText.isEmpty || !attachedImages.isEmpty`
- Swipe-left clear: also clear `attachedImages`

## Implementation Order
1. Create `AttachedImage` struct
2. State changes (singular → array) in MainChatView + GlobalInputBar + draft persistence
3. Screenshot auto-attach (remove banner, append directly to array)
4. New `ImageAttachmentStrip` + `ImageAttachmentPill` components
5. Move image preview from inline to floating strip
6. Update send logic for multi-image
7. Update message bubble for multi-image thumbnails
8. Remove dead code (ScreenshotBanner, old attach/dismiss callbacks)

## Edge Cases
- Max images: cap at ~5 to avoid memory issues (each image is resized Data)
- Screenshots taken while input bar has images: just appends another pill
- Draft switching: `[AttachedImage]` persisted per window
- Empty state: strip hidden when no images attached
- Photo picker: repeated use adds more images (not replaces)
- Duplicate screenshots: if user takes multiple screenshots rapidly, each appends

## Files to Modify
1. `GlobalInputBar+Components.swift` — add `AttachedImage`, `ImageAttachmentStrip`, `ImageAttachmentPill`; remove `ScreenshotBanner`
2. `GlobalInputBar.swift` — remove inline preview + screenshot banner; add strip; update bindings
3. `MainChatView.swift` — `attachedImages: [AttachedImage]`, remove screenshot state, update draft persistence
4. `MainChatView+Utilities.swift` — screenshot auto-attach, remove banner logic
5. `MainChatView+Messaging.swift` — multi-image send logic
6. `Conversation.swift` — add `imageThumbnails: [String]?`
7. `ChatView+MessageBubble.swift` — multi-thumbnail display

## Supersedes
- `plans/testing/screenshot-attach-banner.md` — the banner approach is replaced by auto-attach pills
