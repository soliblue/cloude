# GIF Preview Support {play.rectangle}
<!-- priority: 10 -->
<!-- tags: file-preview -->
<!-- build: 82 -->

> Added animated GIF playback in file preview using native UIImageView animation.

Add animated GIF playback in FilePreviewView. Currently GIFs render as static images.

## Approach
- Add `.gif` content type (separate from `.image`)
- Create `GIFPreview` view using `UIImageView` with `UIViewRepresentable` for native GIF animation
- Extract frames from GIF data via `ImageIO`, set `animationImages` + `animationDuration`
- Support pinch-to-zoom like `ImagePreview`
