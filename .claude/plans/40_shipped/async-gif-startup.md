# Async GIF Decoding on Startup {hare}
<!-- priority: 10 -->
<!-- tags: ui -->
> Move GIF frame decoding off the main thread and cache decoded frames to eliminate startup FPS drop.

## Changes
- AnimatedGIFView now decodes GIF frames asynchronously on first load
- Decoded frames cached statically for instant reuse on view recreation
- Empty state character animation appears after brief async decode instead of blocking startup

## Verify

Outcome: app launches without FPS stutter, empty conversation state shows animated character smoothly.

Test:
1. Cold launch the app (kill and reopen)
2. Verify no visible FPS drop or stutter during initial load
3. Verify the animated Claude character appears and animates correctly in the empty conversation state
4. Navigate away and back to an empty conversation to verify cached frames load instantly
