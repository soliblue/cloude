# Sisyphus Timer Leak Fix
<!-- build: 82 -->

## What
Loading animation ran 2x speed on the 2nd message because `Timer.scheduledTimer` was never invalidated — each `onAppear` stacked a new timer.

## Fix
Replaced `Timer.scheduledTimer` + `@State frameIndex` with `TimelineView(.periodic(...))` which is SwiftUI-native and automatically starts/stops with the view lifecycle. Frame index computed from elapsed time.

## Test
- Send a message, watch the boulder animation
- Send a 2nd message — animation should run at the same speed as the first
