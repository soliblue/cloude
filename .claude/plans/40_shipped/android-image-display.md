---
title: "Android Image Display & Camera"
description: "Inline image rendering in message bubbles, camera capture, and clipboard paste."
created_at: 2026-04-02
tags: ["android", "images", "input"]
build: 120
icon: camera
---
# Android Image Display & Camera


## Context
The image attachments ticket (android-image-attachments, done) covered gallery picker, base64 encoding, thumbnails in input bar, and image count indicator in bubbles. But several sub-features from iOS are missing.

## Missing sub-features

### 1. Inline image rendering in message bubbles
- iOS `MessageBubble+Components.swift` renders actual image thumbnails inline in the message bubble
- Android only shows "X images attached" text indicator, not the actual images
- `ChatMessage` stores `imageCount` but not the image data itself
- Options: store base64 thumbnails in message model (increases memory), or show thumbnails from a cache keyed by message ID
- Even small thumbnails (100-150dp) would be a significant improvement over just text

### 2. Camera capture
- iOS supports camera capture via `UIImagePickerController` in addition to photo library
- Android only uses `ActivityResultContracts.PickMultipleVisualMedia` (gallery only)
- Add: `ActivityResultContracts.TakePicture()` with a camera button alongside the gallery button
- Need to create temp file URI via `FileProvider` for camera output
- Add `<uses-permission android:name="android.permission.CAMERA" />` to manifest

### 3. Clipboard image paste
- iOS detects images on clipboard and shows paste option
- Android: check `ClipboardManager.primaryClip` for image MIME types
- Could add a paste button that appears when clipboard has an image, or detect on input focus

## Implementation notes
Sub-feature 1 is the highest value - users currently can't see what images they sent after the message leaves the input bar. Sub-feature 2 is straightforward with Android's camera contracts. Sub-feature 3 is nice-to-have.

**Files (iOS reference):** MessageBubble+Components.swift, GlobalInputBar+ImageAttachments.swift, ImageEncoder.swift
**Files (Android):** MessageBubble.kt, InputBar.kt, ChatScreen.kt
