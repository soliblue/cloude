---
title: "Streaming Regression Search"
description: "Search commit history to isolate when the major streaming regression appeared and separate it from older known bugs."
created_at: 2026-04-03
tags: ["streaming", "git"]
icon: magnifyingglass
build: 125
---


# Streaming Regression Search

## Bugs
### Agent Name Changes On Completion
The Agent inline pill keeps the same visible name while the response is streaming, including when new tool calls or subagents are appended. The visible name changes only when the message completes. The observed behavior is stable during streaming and changes only on completion. This bug is already present in the oldest tested good checkpoint, commit `25e37126`.

### Major Streaming Regression
There is a later major regression that does not exist at commit `056a5b7a` and is already present at commit `a9dc2391`. At commit `7885d544` the app is deeply broken. This isolates the major break to `a9dc2391`.

## Changelog
- 2026-03-29 21:32:03 +0200
  - commit: `25e37126`
  - title: `build: use distribution signing for release`
  - files changed: `1`
  - result: `good overall; Agent name-change bug present`
  - note: corresponds to the user's remembered build 121 window
  - Agent Bug Present: True
- 2026-03-31 17:28:44 +0200
  - commit: `0680e1d9`
  - title: `ui: add horizontal padding to page indicator tabs`
  - files changed: `1`
  - result: `good`
- 2026-03-31 22:57:00 +0200
  - commit: `aef5a635`
  - title: `perf: eliminate N*60 unnecessary re-renders during streaming`
  - files changed: `2`
  - result: `Agent name-change bug present`
  - Agent Bug Present: True
- 2026-03-31 23:44:54 +0200
  - commit: `a4305ed4`
  - title: `perf: eliminate ConversationView double-subscription and consolidate finalize mutations`
  - files changed: `5`
  - result: `Agent name-change bug present`
  - Agent Bug Present: True
- 2026-03-31 23:56:33 +0200
  - commit: `2f103786`
  - title: `perf: fix FPS degradation during long streaming with equatable frozen blocks`
  - files changed: `3`
  - result: `mostly good; Agent name-change bug present`
  - Agent Bug Present: True
- 2026-04-01 00:16:08 +0200
  - commit: `056a5b7a`
  - title: `perf: remove unnecessary @ObservedObject from 7 views and fix O(n²) split scan`
  - files changed: `9`
  - result: `good; Agent name-change bug present`
  - Agent Bug Present: True
- 2026-04-01 08:26:45 +0200
  - commit: `a9dc2391`
  - title: `perf: enable frozen block split for tool-call streams and incremental parsing`
  - files changed: `2`
  - result: `bad`
  - note: user retest says this checkpoint is broken broken broken
  - StreamingMarkdownView changes: enabled frozen/tail splitting for tool-call streams, adjusted each tool call `textPosition` by the frozen text count before parsing the tail, changed text-only frozen parsing to append parsed delta blocks instead of reparsing the whole frozen prefix, and moved tail block prefixing out of `body` and into `updateIncremental()`
  - Other file changes: `WindowEditSheet+Form` replaced four `@ObservedObject` properties with plain `let` references
- 2026-04-01 08:42:06 +0200
  - commit: `332dcd4d`
  - title: `perf: adaptive throttle for long streams and dead code cleanup`
  - files changed: `3`
  - result: `bad`
  - note: added a 20Hz throttle for `output.$text` updates once live text exceeded 3000 chars in `ObservedMessageBubble`, and removed the unused `isComplete` parameter from `StreamingMarkdownView` plus one dead local variable
- 2026-04-01 15:36:39 +0200
  - commit: `7885d544`
  - title: `refactor: reorganize app into app views stores and parsing`
  - files changed: `165`
  - result: `bad`
  - note: deeply broken

- 2026-04-03 experimental branch `experiment-refactor-no-perf`
  - base: `3b5e78b5` with manual streaming rollback in `Features/Conversation/Views/StreamingMarkdownView.swift` and removal of live text throttle in `Features/Conversation/Views/MessageBubble+LiveWrapper.swift`
  - result: `current best state; all reported issues solved after restoring old tool-group behavior`
  - note: initial experiment fixed the completion-time Agent rename but introduced same-group renames; restoring the old simpler tool-group logic removed that too
  - key logic differences vs `0680e1d9`:
    - `ObservedMessageBubble` still uses local `@State` caches for `liveText` and `liveToolCalls`, fed by `.onReceive`, instead of reading `output.text` and `output.toolCalls` directly in `MessageBubble`
    - `StreamingMarkdownView` still uses the simpler pre-break rule for tool-call messages: any message with tool calls bypasses frozen splitting and renders the whole tool-aware parse in tail
    - `StreamingMarkdownView` still keeps the incremental blank-line split scan cache for pure text streams, plus an equatable frozen section keyed by block count and last block id
    - `ToolGroupView` now matches the older simple behavior again: direct parent/child hierarchy in the view, widgets rendered separately, non-widgets rendered in one horizontal strip, no `ToolGroupLayout` abstraction, and no group-level `.equatable()` gate
    - `InlineToolPill` and `ToolCallLabel` behavior is otherwise modern refactor-era code, but without the later tool-group layout indirection
