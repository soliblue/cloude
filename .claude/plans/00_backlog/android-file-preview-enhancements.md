# Android File Preview Enhancements {doc.richtext}
<!-- priority: 12 -->
<!-- tags: android, files, ui -->

> Add syntax highlighting, JSON tree, and CSV table to file preview.

## Context
The file browser (android-file-browser, done) has directory listing, breadcrumbs, and basic monospace text preview. But the iOS file preview has rich format-specific viewers that are missing on Android.

## Missing sub-features

### 1. Syntax highlighting in file preview
- iOS `FilePreviewView+SourceView.swift` highlights 15+ languages based on file extension
- Android file preview currently shows plain monospace text
- Regex-based highlighting for keywords, strings, comments, numbers
- Language detection from file extension (.kt, .swift, .py, .js, .go, etc.)
- Could share highlighting logic with markdown code block highlighting (android-markdown-enhancements ticket)

### 2. JSON tree viewer
- iOS `FilePreviewView+JSONTree.swift` renders JSON as expandable/collapsible tree
- Nodes show key names, value types, and array counts
- Tap to expand objects/arrays, inline display for primitives
- Android: parse with `kotlinx.serialization.json.JsonElement`, render with recursive composable + `AnimatedVisibility`

### 3. CSV table viewer
- iOS `FilePreviewView+CSVTable.swift` renders CSV as scrollable table with header row
- Column headers styled differently from data rows
- Horizontal scroll for wide tables
- Android: parse CSV lines, render with `LazyColumn` + `Row` with horizontal scroll

### 4. YAML viewer
- iOS `FilePreviewView+YAMLParser.swift` renders YAML as hierarchical tree
- Similar to JSON tree but for YAML structure
- Lower priority than JSON/CSV

### 5. Audio/video preview
- iOS `FilePreviewView+AudioPreview.swift` has audio playback controls
- iOS supports video file preview
- Android: `MediaPlayer` or `ExoPlayer` for audio, `VideoView` for video
- Lower priority

## Implementation notes
Sub-features 1-3 are the high-value items. All changes are in the file preview composable (likely `FileBrowserScreen.kt` or a preview sheet). Syntax highlighting could be extracted into a shared utility used by both file preview and markdown code blocks.

**Files (iOS reference):** FilePreviewView+SourceView.swift, FilePreviewView+JSONTree.swift, FilePreviewView+CSVTable.swift, FilePreviewView+YAMLParser.swift, FilePreviewView+AudioPreview.swift
