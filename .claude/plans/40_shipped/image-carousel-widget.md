---
title: "Image Carousel Widget"
description: "Added inline image carousel widget with swipeable images and tap-to-preview."
created_at: 2026-03-06
tags: ["widget", "ui"]
icon: photo.on.rectangle
build: 82
---


# Image Carousel Widget
## Changes
- `CloudeApp.swift`: Added `.environmentObject(connection)` so widgets can access ConnectionManager
- `widgets-mcp/server.js`: Added `image_carousel` tool (accepts `images` array with `path`/`url` + optional `caption`)
- `WidgetView+ImageCarousel.swift`: New widget with `ImageCarouselWidget` + `FileImageView` helper
- `WidgetView+Registry.swift`: Registered with `photo.on.rectangle` icon, green accent

## How it works
- File paths: uses `connection.getFile()` + file cache (same as FilePreviewView)
- URLs: uses SwiftUI `AsyncImage`
- Tap path image: opens FilePreviewView sheet
- Tap URL image: opens URL in browser
- No agent changes needed
