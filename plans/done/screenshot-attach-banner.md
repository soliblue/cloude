# Screenshot Attach Banner

## Context
When the user takes a screenshot on their iPhone, there's no way to quickly attach it to the current chat. The goal is to detect the screenshot, show a brief banner above the input bar with an "attach" action, and auto-dismiss after 5 seconds.

## Approach

### 1. Detect screenshot in MainChatView
- Use `NotificationCenter.default.publisher(for: UIApplication.userDidTakeScreenshotNotification)` in MainChatView
- On notification, capture the screenshot image from the photo library (latest photo) using PHAsset
- Store it as `@State var screenshotData: Data?` which drives the banner visibility
- Auto-dismiss after 5 seconds via `DispatchQueue.main.asyncAfter`

**Note:** `userDidTakeScreenshotNotification` fires *after* the screenshot is taken, so we can fetch the latest image from Photos.

### 2. Create ScreenshotBanner component
Add to `GlobalInputBar+Components.swift`, following the PendingAudioBanner pattern:

```
ScreenshotBanner
├── HStack(spacing: 12)
│   ├── Screenshot thumbnail (36x36 rounded)
│   ├── Spacer
│   ├── Dismiss button (xmark.circle.fill)
│   └── Attach button (paperclip.circle.fill)
├── .ultraThinMaterial background
├── .transition(.move(edge: .top).combined(with: .opacity))
└── Auto-dismiss after 5 seconds
```

Actions:
- **Attach** (paperclip icon): Sets `selectedImageData` to the screenshot data, dismisses banner
- **Dismiss** (xmark icon): Just dismisses the banner

Keep it minimal - just thumbnail + two SF Symbol buttons, no text label needed.

### 3. Wire into GlobalInputBar
- Add `screenshotData: Data?` binding + `onDismissScreenshot: () -> Void` callback to GlobalInputBar
- Show the banner above the input field (same spot as PendingAudioBanner)

### 4. Wire into MainChatView
- Add `@State var screenshotData: Data?`
- Listen for screenshot notification, fetch latest photo, set state
- Pass binding + callbacks to GlobalInputBar
- On attach: set `selectedImageData = screenshotData`, clear `screenshotData`
- Auto-dismiss timer: clear `screenshotData` after 5s

## Files to modify
1. **`Cloude/Cloude/UI/GlobalInputBar+Components.swift`** - Add ScreenshotBanner view
2. **`Cloude/Cloude/UI/GlobalInputBar.swift`** - Add screenshotData binding, show banner
3. **`Cloude/Cloude/UI/MainChatView.swift`** - Screenshot notification listener, state, pass to input bar

## Verification
1. Build the app
2. Take a screenshot on the phone
3. Banner should appear above input bar with thumbnail + attach/dismiss buttons
4. Tapping attach puts the screenshot in the input bar image slot
5. Banner auto-dismisses after 5 seconds if no action taken
6. Tapping dismiss removes the banner immediately
