---
title: "Reliable Scroll-to-Bottom"
description: "Fixed streaming auto-scroll with isolated invalidation, boosting FPS from ~10 to 55+ during streaming."
created_at: 2026-03-18
tags: ["ui", "streaming"]
icon: arrow.down.to.line
build: 86
---


# Reliable Scroll-to-Bottom
## Status
Streaming auto-scroll is solved. Two remaining gaps for full scroll reliability.

## What We Did

### Phase 1: Isolate streaming invalidation [DONE - f603a9b]
Changed `ConversationOutput.text` didSet to only cascade `parent?.objectWillChange.send()` on empty/non-empty transitions (~2x per response instead of 60Hz). Created `StreamingContentObserver` that observes `ConversationOutput` directly via `@ObservedObject`. Only the streaming bubble re-renders per token now. FPS went from ~10 to 55+ during streaming+scrolling.

### Phase 2: Incremental markdown parsing [DONE - f603a9b]
`StreamingMarkdownView` now splits text at stable boundaries (last blank line outside code fences). Completed paragraphs are cached as `frozenBlocks` and never reparsed. Only the active tail is reparsed on each token. Eliminated main-thread contention between markdown parsing and scroll layout.

### Phase 3: Scroll detection fix [DONE - 5205068]
Replaced `DragGesture` + `TapGesture` with `onScrollPhaseChange` (iOS 18) for `userHasScrolled` detection. The old `TapGesture` was marking `userHasScrolled = true` on any tap, suppressing auto-scroll unexpectedly. Now only actual scroll interaction (`.interacting` phase) sets the flag.

### Phase 4: ScrollPosition API migration [ATTEMPTED - REVERTED]
Attempted full migration to `.scrollPosition($position)` binding. Reassigning `ScrollPosition` objects destroyed scroll continuity during rapid content changes, causing content to disappear mid-stream. Reverted to anchor approach.

### Phase 5: Simplify to defaultScrollAnchor only [DONE - current]
Removed invisible anchor (`Color.clear.frame(height: 80).id(bottomId)`), scroll-to-bottom button, `ScrollViewReader`, `scrollProxy`, `isBottomVisible`, `userHasScrolled`, `bottomId`, and question section (`QuestionView`, `PendingQuestion`). Entire scroll system is now just `.defaultScrollAnchor(.bottom)`.

Result: streaming auto-scroll is super clean. `.defaultScrollAnchor(.bottom)` handles initial load and streaming perfectly with zero programmatic scrolling.

### UI commit throttle [REJECTED]
Tested throttling to 20Hz during drag. Made streaming feel laggy with no benefit since Phase 1+2 already solved the performance issue. Reverted.

## Remaining Gaps

### 1. Auto-scroll to bottom on send message
`.defaultScrollAnchor(.bottom)` only works when the viewport is already at the bottom. When the keyboard dismisses after sending a message, the viewport shifts and the anchor loses grip. Need one programmatic scroll when a user message is added. Must avoid double-scrolling if already at bottom.

### 2. Scroll-to-bottom button
Currently removed. Need to add back a way for users to jump to bottom when scrolled up reading history. Options:
- `ScrollPosition.scrollTo(edge: .bottom)` (no anchor ID needed)
- `ScrollViewReader` + scroll to last message ID

## Files
- `Cloude/Cloude/UI/ConversationView+Components.swift` -- scroll handling, LazyVStack, StreamingContentObserver
- `Cloude/Cloude/Services/ConnectionManager+ConversationOutput.swift` -- CADisplayLink drain, objectWillChange cascading
- `Cloude/Cloude/UI/ConversationView.swift` -- passes conversationOutput to ChatMessageList
- `Cloude/Cloude/UI/MainChatView+HeartbeatChat.swift` -- passes conversationOutput for heartbeat
- `Cloude/Cloude/UI/StreamingMarkdownView.swift` -- incremental markdown parsing, frozenBlocks/tailBlocks
