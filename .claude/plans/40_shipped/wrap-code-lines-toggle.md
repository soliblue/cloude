---
title: "Wrap Code Lines Toggle"
description: "Added persistent toggle for code line wrapping in file preview with toolbar button and settings row."
created_at: 2026-03-03
tags: ["file-preview", "settings"]
icon: arrow.turn.down.right
build: 82
---


# Wrap Code Lines Toggle
## Changes
- `FilePreviewView.swift`: Added `@AppStorage("wrapCodeLines")` + toolbar toggle button
- `FilePreviewView+Content.swift`: `sourceTextView` respects wrap preference (horizontal scroll when off)
- `SettingsView.swift`: Added "Wrap Code Lines" toggle in preferences section

Default: wrap on (matches current behavior).
