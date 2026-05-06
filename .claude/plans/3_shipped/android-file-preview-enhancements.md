---
title: "Android File Preview Enhancements"
description: "Add syntax highlighting, JSON tree, CSV table, YAML viewer, media preview, and image preview to file browser."
created_at: 2026-03-30
tags: ["android", "files", "ui"]
icon: doc.richtext
build: 120
---
# Android File Preview Enhancements


## Completed

### 1. Syntax highlighting
- Regex-based highlighting for 15+ languages (keywords, strings, comments, numbers, types)
- Language detection from file extension
- `SyntaxHighlighter.kt` - reusable utility

### 2. JSON tree viewer
- Expandable/collapsible tree with sorted keys
- Color-coded values (strings, numbers, booleans, null)
- `JSONTreeViewer.kt`

### 3. CSV/TSV table viewer
- Scrollable table with sticky header row
- RFC 4180 compliant parsing (quoted fields, escaped quotes)
- `CSVTableViewer.kt`

### 4. YAML viewer
- Custom YAML parser (indentation-based, inline arrays, multi-doc)
- Converts to JSON and reuses JSONTreeViewer
- `YAMLParser.kt`, `YAMLTreeViewer.kt`

### 5. Audio/video preview
- Audio: MediaPlayer with play/pause, progress bar, time display
- Video: VideoView with auto-play, 16:9 aspect ratio
- `MediaPreview.kt`

### 6. Image preview
- BitmapFactory decoding from raw bytes
- Fit-to-container display
- Supports PNG, JPG, GIF, WebP, BMP, ICO

### 7. Large file support (chunk reassembly)
- Files >512KB are chunked by server into multiple `file_chunk` messages
- Added chunk reassembly in `EnvironmentConnection.kt` (matching iOS pattern)
- Emits synthetic `FileContent` event when all chunks arrive
- Fixed race condition with async/await pattern for SharedFlow

## Files
- `android/.../UI/files/SyntaxHighlighter.kt`
- `android/.../UI/files/JSONTreeViewer.kt`
- `android/.../UI/files/CSVTableViewer.kt`
- `android/.../UI/files/YAMLParser.kt`
- `android/.../UI/files/YAMLTreeViewer.kt`
- `android/.../UI/files/MediaPreview.kt`
- `android/.../UI/files/FileBrowserScreen.kt`
- `android/.../Services/EnvironmentConnection.kt`
