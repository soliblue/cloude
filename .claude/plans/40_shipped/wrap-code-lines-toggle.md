# Wrap Code Lines Toggle {arrow.turn.down.right}
<!-- priority: 10 -->
<!-- tags: file-preview, settings -->
<!-- build: 82 -->

> Added persistent toggle for code line wrapping in file preview with toolbar button and settings row.

## Changes
- `FilePreviewView.swift`: Added `@AppStorage("wrapCodeLines")` + toolbar toggle button
- `FilePreviewView+Content.swift`: `sourceTextView` respects wrap preference (horizontal scroll when off)
- `SettingsView.swift`: Added "Wrap Code Lines" toggle in preferences section

Default: wrap on (matches current behavior).
