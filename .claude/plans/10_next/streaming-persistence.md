# Streaming Persistence {tray.and.arrow.down}
<!-- priority: 8 -->
<!-- tags: streaming, reliability -->

> Live message text only gets written to the SwiftData model when `finalizeStreamingMessage` runs at completion. If the app is killed mid-stream, the persisted message has empty text and disappears on next launch.

## Problem

Unified streaming inserts an empty `ChatMessage` upfront and reads from `ConversationOutput` in memory during streaming. The model only gets the final text when `finalizeStreamingMessage` runs. If the app goes to background and iOS kills it, or a crash occurs, the stored message remains empty.

On `main` (pre-unified), there was no persisted message during streaming at all, so a kill just lost the response silently. Now the empty placeholder persists and looks like a disappeared message.

## Options Considered

1. **Write to model on every chunk** - String copy + SwiftData dirty-marking dozens of times per second. SwiftUI observation tracks per-property per-instance, and the live bubble reads from `ConversationOutput` not `message.text`, so in theory no extra renders. But untested at scale.

2. **Throttled timer** - Write every N seconds. Same observation question, lower frequency. Adds timer complexity.

3. **Scene phase flush** - Write `output.text` into `message.text` on `.background`/`.inactive`. Zero cost during streaming, catches the most common case (user switches app, screen locks). Misses crashes and force-quits, but those also lost everything pre-unified.

## Recommended Fix

Scene phase flush (option 3) as the minimal, zero-performance-impact solution:

- On scene phase `.background`/`.inactive`: if streaming is active, write `output.text` into the live `ChatMessage`
- On app launch: clean up any messages with empty text that aren't actively streaming (ghost placeholders from kills/crashes)
- No timers, no per-chunk writes, no performance impact during normal streaming

## Tasks

- [ ] Flush live message text on scene phase change to `.background`/`.inactive`
- [ ] Clean up empty ghost messages on app launch
- [ ] Test: background app mid-stream, reopen, message text is preserved
- [ ] Test: force-quit mid-stream, reopen, no empty ghost bubble
