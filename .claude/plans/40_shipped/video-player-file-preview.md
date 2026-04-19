---
title: "Video Player in File Preview"
description: "Added native video playback with AVPlayer for MP4 files in the file preview view."
created_at: 2026-02-09
tags: ["ui", "file-preview"]
icon: play.fill
build: 69
---


# Video Player in File Preview
## Desired Outcome

Tapping an .mp4 file path (file pill) opens a video player with play/pause, scrubbing, and fullscreen. Same UX pattern as image preview but with AVPlayer.

**Files:** `FilePreviewView.swift`, possibly `InlineTextView.swift` (file pill detection)
