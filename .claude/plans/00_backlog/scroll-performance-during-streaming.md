# Scroll Performance During Streaming

Scrolling during active streaming still feels slightly laggy. The redundant state update fix helped but didn't fully resolve it.

## Possible causes
- `onChange(of: currentOutput)` fires on every token, triggering view re-evaluation even when not scrolling to bottom
- `DragGesture` on `ScrollView` may conflict with native scroll gesture recognition
- `LazyVStack` re-layout during rapid content growth while user is mid-scroll
- `isBottomVisible` tracking via `onAppear`/`onDisappear` on the bottom anchor may cause extra layout passes

## Ideas to explore
- Replace `DragGesture` with `UIScrollViewDelegate` via `UIViewRepresentable` for native scroll detection
- Debounce or throttle the `currentOutput` onChange handler
- Use `scrollPosition` API (iOS 17+) instead of `ScrollViewReader` + manual tracking
- Profile with Instruments to identify the actual bottleneck
