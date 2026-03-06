# Image Carousel Widget

Display images inline in chat. Single image shows directly, multiple images as swipeable carousel with page dots. Tap opens FilePreviewView.

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
