# Wrap Code Lines Toggle
<!-- build: 82 -->

Add a persistent user preference for wrapping code lines in file preview.

## Changes
- `FilePreviewView.swift`: Added `@AppStorage("wrapCodeLines")` + toolbar toggle button
- `FilePreviewView+Content.swift`: `sourceTextView` respects wrap preference (horizontal scroll when off)
- `SettingsView.swift`: Added "Wrap Code Lines" toggle in preferences section

Default: wrap on (matches current behavior).
