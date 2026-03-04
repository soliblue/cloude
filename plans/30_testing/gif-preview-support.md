# GIF Preview Support

Add animated GIF playback in FilePreviewView. Currently GIFs render as static images.

## Approach
- Add `.gif` content type (separate from `.image`)
- Create `GIFPreview` view using `UIImageView` with `UIViewRepresentable` for native GIF animation
- Extract frames from GIF data via `ImageIO`, set `animationImages` + `animationDuration`
- Support pinch-to-zoom like `ImagePreview`
