---
title: "GIF Preview Support"
description: "Added animated GIF playback in file preview using native UIImageView animation."
created_at: 2026-03-04
tags: ["file-preview"]
icon: play.rectangle
build: 82
---


# GIF Preview Support {play.rectangle}
Add animated GIF playback in FilePreviewView. Currently GIFs render as static images.

## Approach
- Add `.gif` content type (separate from `.image`)
- Create `GIFPreview` view using `UIImageView` with `UIViewRepresentable` for native GIF animation
- Extract frames from GIF data via `ImageIO`, set `animationImages` + `animationDuration`
- Support pinch-to-zoom like `ImagePreview`
