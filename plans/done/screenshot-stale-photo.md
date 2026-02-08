# Screenshot Attaches Stale Photo
<!-- priority: 10 -->
<!-- build: 56 -->

## Problem
When taking a screenshot on iOS, the `userDidTakeScreenshotNotification` fires before the screenshot is saved to the photo library. `loadLatestPhoto()` then fetches the previous latest photo instead of the one just taken.

## Fix
Added 0.5s delay before fetching from the photo library, giving iOS time to complete the write.

## File Changed
- `Cloude/Cloude/UI/MainChatView+Utilities.swift` — `fetchLatestScreenshot()`

## Test
1. Take a screenshot on iOS — the attached image should be the screenshot you just took, not an older one
2. Take multiple screenshots in succession — each should attach the correct one
