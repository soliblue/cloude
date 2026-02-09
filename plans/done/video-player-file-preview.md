# Video Player in File Preview

MP4 files (like Sora-generated videos) currently have no playback support in the iOS app. They show as raw files with no preview. Need native video playback like we have for images.

## Desired Outcome

Tapping an .mp4 file path (file pill) opens a video player with play/pause, scrubbing, and fullscreen. Same UX pattern as image preview but with AVPlayer.

**Files:** `FilePreviewView.swift`, possibly `InlineTextView.swift` (file pill detection)
