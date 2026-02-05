# Streaming Text UX Plan

## The Problem (How It Feels Today)

Using Cloude right now, streaming text feels like watching someone paste chunks into a text field. Words appear in irregular bursts — three words, pause, eight words, pause, one word. The rhythm is dictated by network timing, not human reading. It feels mechanical and anxious, like watching a loading bar that keeps stuttering.

Compare to ChatGPT or Claude.ai: text flows in like someone is writing it. Steady, calm, readable. You can actually read along as it appears. That flow is the difference between "I'm waiting for a computer" and "I'm reading what someone is saying."

## Why It Matters For Your Life

This isn't cosmetic polish. When you're on your phone checking what an agent did, reading a plan, or following a streaming response while walking — the feel of text arrival determines whether you can actually read in real time or have to wait for it to finish and then scroll back up. Smooth streaming means:

- **You can read along as it writes** — the text arrives at a pace your eyes can track
- **You don't lose your place** — if you're reading something above, the viewport doesn't jump
- **Less anxiety** — stuttery text makes you wonder "is it still working?" Steady flow feels alive
- **Phone feels like a real terminal** — the gap between "mobile viewer" and "real tool" shrinks

## Current Architecture (What's Broken)

### The Streaming Path Today
```
WebSocket chunk arrives (irregular timing, 20-500ms gaps)
  → ConnectionManager appends to ConversationOutput.text (raw string concat)
    → @Published fires objectWillChange
      → SwiftUI re-renders StreamingMarkdownView
        → StreamingMarkdownParser.parse() re-tokenizes ENTIRE string from scratch
          → buildTree() rebuilds ENTIRE content tree
            → SwiftUI diffs and re-renders all blocks
```

### Problem 1: Network = Display (no buffer)
Every WebSocket chunk triggers an immediate render. If the network sends 3 tokens at once, then pauses 200ms, then sends 1 token — that's exactly what you see. The visual rhythm is enslaved to network jitter.

### Problem 2: O(n²) Parsing
`StreamingMarkdownParser.parse()` processes the entire accumulated text on every chunk. A 10KB response that arrives in 100 chunks means parsing: 100B + 200B + 300B + ... + 10KB = ~5MB of total parsing work. Gets worse as responses get longer.

### Problem 3: No Animation
Text pops. No easing, no transition, no flow. The layout just jumps to accommodate new content.

### Problem 4: Scroll Position Not Managed
Currently: when you send a message, it scrolls to show your message at top. After that, no auto-scroll during streaming. New content grows below the fold silently. You have to manually scroll to see it, or wait and scroll down after.

If auto-scroll were naive (always scroll to bottom), you couldn't read earlier content during streaming — it would keep yanking you down.

## How The Big Apps Solve This

### ChatGPT (iOS + Web)
- **Word buffer**: Tokens arrive from API, go into a buffer. A timer drains the buffer at ~30-50ms per word, creating a steady visual cadence regardless of network timing
- **Batch state updates**: Instead of re-rendering per token, they batch ~50ms of accumulated tokens into a single state update (~20 renders/sec max)
- **Scroll pause**: During long responses, auto-scroll stops and a "scroll to bottom" button appears. Respects the reader

### Claude.ai (Web)
- **Character-level drip**: Uses `requestAnimationFrame` with ~5ms per character (200 chars/sec). Feels fast but steady
- **Intersection Observer**: Only processes visible elements, saving ~60% CPU on long responses
- **Markdown parsed incrementally**: New content appended to existing parsed tree, not re-parsed from scratch

### The Universal Pattern
```
Network chunks → Buffer (absorb jitter) → Steady timer → Display (word-by-word)
```
The key insight: **decouple network from display**. The buffer is the shock absorber.

## Implementation Status

- **Phase 1 (Display Buffer)**: DONE — built into `ConversationOutput` with `CADisplayLink`, 300 chars/sec base rate, adaptive speedup
- **Phase 2 (Incremental Parsing)**: Not started
- **Phase 3 (Scroll Behavior)**: DONE — pin-to-bottom tracking, auto-scroll when pinned, unpin on drag, re-pin on send/tap
- **Phase 4 (Animation)**: Not started

## Proposed Implementation

### Phase 1 — Display Buffer (biggest bang, do this first) ✅

Add a `StreamingDisplayBuffer` between the WebSocket and the UI:

```
WebSocket chunk arrives
  → Appends to pendingBuffer (not displayed yet)
    → DisplayLink timer fires every frame (~16ms)
      → Drains N characters from buffer into displayedText
        → SwiftUI renders only what's in displayedText
```

**Draining strategy:**
- Normal text: ~5ms per character (200 chars/sec) — fast enough to feel real-time, slow enough to read along
- Code blocks: drain line-by-line (don't break mid-line, code is read by line)
- When streaming ends (isRunning → false): flush entire remaining buffer instantly
- When buffer is empty and more arrives: resume draining at same cadence
- Adaptive speed: if buffer grows > 500 chars behind, speed up drain rate to catch up without falling too far behind

**Why this is Phase 1**: Even without fixing parsing or adding animation, just making text appear at a steady rhythm instead of network-jitter bursts will transform the feel. It's the single highest-impact change.

Key files:
- New: `StreamingDisplayBuffer.swift` (the buffer + timer)
- Modify: `ConnectionManager+API.swift:66` (feed buffer instead of direct text append)
- Modify: `StreamingMarkdownView.swift` (read from displayed text)

### Phase 2 — Incremental Parsing

Stop re-parsing the entire string every time:

1. Track `lastParsedPosition` in the text
2. When new text arrives, only parse from `lastParsedPosition` forward
3. Handle the "last block might be incomplete" case: re-parse only the final block + new content
4. Append new blocks to existing array, keeping old blocks stable
5. This makes SwiftUI diffing cheap — old blocks have same identity, only new ones added

**Edge cases to handle:**
- A code fence opened but not yet closed (```) — keep it as "in progress" until close arrives
- A table row that's still being typed — don't render until newline confirms it
- Headers mid-line — wait for newline

**Impact**: Turns O(n²) parsing into O(n). For a 20KB response, that's ~100x less work. Directly reduces CPU heat on phone during long streams.

Key files:
- Modify: `StreamingMarkdownParser.swift` (add incremental mode)
- Modify: `StreamingMarkdownView.swift` (stable block identities, append-only updates)

### Phase 3 — Scroll Behavior ✅

The scroll system needs to understand intent:

**State: "pinned to bottom"**
- Default true when you send a message
- True when bottom of content is within ~50pt of viewport bottom
- False the moment you scroll up manually (drag gesture)

**When pinned:**
- As new displayed text appears, smoothly scroll to keep bottom visible
- Use `.scrollTo(bottomId, anchor: .bottom)` on a debounced timer (not every character — every ~100ms)

**When NOT pinned (you're reading something above):**
- Viewport stays exactly where it is. New content grows below, invisible
- Show a floating pill at bottom: "↓ New content" (with a subtle pulse or count)
- Tapping the pill: smooth scroll to bottom, re-pin
- Sending a new message: always re-pin

**Why this matters**: This is the difference between "I can use this while it's running" and "I have to wait for it to finish." If you can read old content while new content streams below, the phone becomes a real tool, not just a viewer.

Key files:
- Modify: `ProjectChatView+Components.swift` (scroll tracking, pin state)
- Already has `scrollOffset` tracking and `showScrollToBottom` — extend this

### Phase 4 — Subtle Animation (optional polish)

Once the buffer and scroll are right, add micro-animations:

- **Layout growth**: `.animation(.easeOut(duration: 0.15), value: displayedText.count)` on the text container so it doesn't jump-resize
- **New block entrance**: Fade in new markdown blocks with `.transition(.opacity.animation(.easeIn(duration: 0.1)))`
- **Cursor indicator**: A small blinking cursor or pulsing dot at the end of streaming text, like a typing indicator that shows where new text will appear

**Don't overdo it**: The buffer already handles 80% of the feel. Animation is sauce, not the meal. If it causes any performance hit on older iPhones, skip it.

## Architecture Notes

- `StreamingDisplayBuffer` should be `@Observable`, owned by or associated with `ConversationOutput`
- Use `CADisplayLink` for frame-aligned drain (fires every screen refresh, ~60-120hz). Better than `Timer` because it syncs with actual frame rendering
- Buffer should be a simple `String` with an index tracking how far we've drained. No need for complex queue structures
- The buffer is per-conversation (already isolated via `ConversationOutput`)
- On conversation switch: show full accumulated text instantly (don't replay the buffer animation)

## Implementation Order & Dependencies

```
Phase 1 (Buffer)     → immediate feel improvement, no other changes needed
Phase 2 (Parsing)    → performance, independent of Phase 1
Phase 3 (Scroll)     → needs Phase 1 (smooth scroll requires steady text growth)
Phase 4 (Animation)  → needs Phase 1 + 3 (animation on top of jittery text looks worse)
```

Phase 1 alone gets us 80% there. Phases 1+3 together get us 95%. The rest is polish.

## References
- [Smooth Text Streaming in AI SDK v5](https://upstash.com/blog/smooth-streaming) — 5ms/char, requestAnimationFrame, buffer pattern
- [Why React Apps Lag With Streaming Text (ChatGPT approach)](https://akashbuilds.com/blog/chatgpt-stream-text-react) — 50ms batch, ref buffering, 20 renders/sec
- [Replicating ChatGPT's typing animation in SwiftUI](https://medium.com/@ganeshrajugalla/swiftui-replicating-chatgpts-typing-like-animation-in-swiftui-913ba08a323a)
- [Streaming Text Like an LLM with TypeIt](https://macarthur.me/posts/streaming-text-with-typeit/)
- SwiftUI `TextRenderer` protocol (iOS 17+), `CADisplayLink` for frame-synced output
