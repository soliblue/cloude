# Streaming Text Fade-In Animation

## Problem
During streaming, text chunks appear at full opacity instantly (~5 chars per frame at 300 chars/sec). The user wants characters to fade in smoothly from left to right, creating a fluid reveal effect rather than abrupt appearance.

## Current Architecture
- `ConversationOutput` has a queue (`fullText`) and a CADisplayLink drain (`drainTick`) at 300 chars/sec
- Every tick, `text` is set to `fullText[0..<displayIndex]`, which fires `@Published` and triggers SwiftUI re-render
- `StreamingMarkdownView` parses the text into blocks and renders via `Text(attributed)` views
- The drip mechanism itself IS the animation - it feeds characters gradually. The issue is each batch appears at full opacity with no visual transition

## What Was Tried (and Failed)

### 1. `.contentTransition(.interpolate)` + `.animation(.easeOut(0.6))` on VStack
- **Commit 27b9bf9** (original, worked on main)
- **Removed in 356a3a6** because it animated layout changes (new blocks appearing caused jumps)
- Re-applied on `unified-streaming` branch: **no visible effect**
- Theory: worked on main because streaming view was a standalone LazyVStack item (not inside ForEach). Inside ForEach, implicit animations may be suppressed

### 2. `.animation()` per-ContentNodeView instead of VStack
- Applied `.animation(.easeOut(0.6), value: text)` to each ContentNodeView instead of the whole VStack
- **No visible effect** - same as above

### 3. `.animation()` per-Text-view
- Applied directly to `Text(attributed).animation(.easeOut(0.3), value: attributed)`
- **No visible effect** - rapid 16ms updates restart the animation before it completes

### 4. `withAnimation` in `drainTick()`
- Wrapped `text = newText` in `withAnimation(.easeOut(duration: 0.4))` to force animation transaction
- **Not tested thoroughly** but would also animate layout changes (same issue as #1)

### 5. Lightweight `ObservedMessageBubble` bypassing `MessageBubble`
- Rendered streaming content directly (like old `StreamingContentObserver`) instead of going through `MessageBubble`
- User rejected: defeats the purpose of unified streaming

## Key Insight
`.contentTransition(.interpolate)` works by cross-fading between two text states. With 60fps updates every 16ms, each animation is immediately cancelled by the next. The old setup might have looked smooth because:
1. The streaming view had a different structural position in the view tree (standalone vs ForEach item)
2. Or the subtle cross-fade at 0.6s duration created enough overlap to look smooth, but only in certain view configurations

## Approaches Not Yet Tried

### A. Per-character opacity via AttributedString
- Track a "fade edge" - the last ~8-10 characters of displayed text get graduated opacity
- Modify the last tail block's `AttributedString` to apply `foregroundColor(.primary.opacity(x))` to trailing chars
- As the drip advances, old chars become fully opaque, new chars start faded
- **Pro**: deterministic, no SwiftUI animation system dependency
- **Con**: needs plumbing to identify the "last block" in the content tree; might override markdown foreground colors
- **Complexity**: medium - need to pass `isFading` through ContentNodeView to last StreamingBlockView

### B. Two-phase drip in ConversationOutput
- Instead of one `displayIndex`, use two: `opaqueIndex` (fully visible) and `visibleIndex` (partially visible)
- `visibleIndex` advances at current rate, `opaqueIndex` trails by ~10 chars
- Publish both the text AND the fade boundary offset
- View applies opacity based on the boundary
- **Pro**: fade logic lives in ConversationOutput, view just reads the data
- **Con**: same AttributedString modification needed in the view

### C. Gradient mask overlay
- Apply a horizontal gradient mask at the trailing edge of the streaming text
- Simple CSS-like approach: last ~30px fades from opaque to transparent
- **Pro**: dead simple, no per-character work
- **Con**: masks actual text content; only works at the right edge of the view, not at the text cursor position

### D. Investigate LazyVStack animation suppression
- Test if the same `.contentTransition(.interpolate)` setup works when the streaming view is NOT inside a ForEach item
- Could add the streaming view as a separate section (like old code) but pointing to the same message
- **Pro**: minimal code change if it works
- **Con**: may break unified streaming identity preservation

## Recommendation
Start with **A** (per-character opacity via AttributedString). It's the most reliable approach since it doesn't depend on SwiftUI's animation system at all. The fade is baked into the data, not the rendering pipeline.

## Branch
All unified streaming work is on `unified-streaming`. The core refactor (no flicker on completion) is working. This ticket is specifically about the fade animation.
