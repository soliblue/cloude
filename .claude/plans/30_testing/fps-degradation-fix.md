# FPS Degradation Fix {gauge.with.dots.needle.bottom.50percent}
<!-- priority: 10 -->
<!-- tags: performance, streaming -->
> Fix FPS degradation during long markdown streaming by making frozen blocks layout-free and stableSplitPoint incremental.

## Changes

### 1. Equatable FrozenBlocksSection
- Extracted frozen blocks into a separate `FrozenBlocksSection: View, Equatable`
- Uses `.equatable()` modifier so SwiftUI skips body evaluation when blocks haven't changed
- Equality based on block count + last block ID (frozen blocks are append-only)

### 2. Incremental stableSplitPoint
- Caches the scan offset, fence state, and last blank line offset between calls
- On new text, only scans the newly appended portion
- Turns O(n) per frame into O(delta) per frame

## Verify

Outcome: FPS stays above 50 throughout a long streaming response.

Test:
1. Open a conversation with haiku model
2. Send: "Write a long markdown answer with 8 sections, headings, bullet lists, and a short table about the architecture of this repo."
3. Watch FPS in logs: `grep "debug sample" app-debug.log | tail -20`
4. FPS should stay 50+ throughout, not degrade below 30
5. Also test a tool call prompt to verify that path still renders correctly
