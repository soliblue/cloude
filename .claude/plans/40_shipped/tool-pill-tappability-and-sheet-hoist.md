---
title: "Tool Pill Tappability + Sheet Hoist"
description: "Fix untappable tool pills near the input bar, stabilize streaming tool block IDs, and hoist the tool detail sheet out of the lazy stack."
created_at: 2026-04-01
tags: ["performance", "bug-fix", "streaming"]
icon: hand.tap
build: 122
---


# Tool Pill Tappability + Sheet Hoist

## Problem

Three separate issues making tool call pills unreliable:

1. **Pills near input bar untappable**: Tapping a tool pill near the bottom of the screen showed button visual feedback but the sheet never opened. Scrolling the pill away from the input bar made it work.

2. **Unstable block IDs during streaming**: Tool group block IDs used `tools-\(currentPosition)` where `currentPosition` was the adjusted position in the tail region. As `frozenCharCount` grew during streaming, the adjusted position changed every frame, causing SwiftUI to destroy/recreate pill views and kill gesture recognizers mid-tap.

3. **FPS drop when opening tool detail sheet**: Every `MessageBubble` inside the `LazyVStack` carried its own `.sheet(item:)` modifier. Opening a sheet from inside a lazy stack causes SwiftUI layout thrashing as it manages sheet lifecycle across recycled views.

## Root Causes

### Input bar hit area stealing taps
`WorkspaceView+InputSection.swift` had:
```swift
.contentShape(.interaction, ExpandedTopRect(expansion: DS.Size.l))
.onTapGesture { }
```
The `ExpandedTopRect` shape extended the input section's hit-test area upward by `DS.Size.l` pixels. The empty `.onTapGesture` consumed taps in that zone, blocking buttons on pills positioned near the bottom of the screen.

### Position-based block IDs
`StreamingMarkdownParser+ToolCalls.swift` used `tools-\(currentPosition)` for tool group IDs. During streaming with frozen/tail split, `currentPosition` is relative to the tail region and shifts every time `frozenCharCount` changes. SwiftUI interprets changing IDs as view destruction + recreation, which kills in-flight gesture recognizers.

### Sheet inside LazyVStack
Each `MessageBubble` owned `@State selectedToolDetail` and had `.sheet(item:)` on its `messageContent`. With N messages in a `LazyVStack`, N sheet modifiers exist. SwiftUI must track sheet presentation state across view recycling, causing unnecessary layout work on presentation.

## Fixes

### 1. Remove expanded input hit area
Deleted `ExpandedTopRect` shape and the empty `.onTapGesture` from `WorkspaceView+InputSection.swift`. The VStack's natural bounds are sufficient.

### 2. Stable toolId-based block IDs
Changed both group creation points in `StreamingMarkdownParser+ToolCalls.swift` from `tools-\(currentPosition)` to `tools-\(pendingTools[0].toolId)`. Tool IDs are globally unique and never change, so block identity is stable across streaming frames.

Also fixed: tools with `textPosition > text.count` (future-position) now skip with `continue` instead of being included in the current parse. Text segment prefixes use `s\(currentPosition)` instead of `s\(segmentIndex)` for consistency.

### 3. Hoist sheet to ChatMessageList
Moved `@State selectedToolDetail` and `.sheet(item:)` from individual `MessageBubble` instances to `ChatMessageList`. Single sheet modifier on the scroll view. Pills communicate selection upward via `onSelectToolDetail` callback passed through `ObservedMessageBubble` and `MessageBubble`.

### 4. ToolGroupView Equatable
Added `Equatable` conformance to `ToolGroupView` comparing `blockId` + tool IDs + tool states. Applied `.equatable()` modifier. SwiftUI skips body re-evaluation when tools haven't actually changed.

### 5. FrozenBlocksSection improvements
- Added `onSelectTool` passthrough so frozen tool pills are tappable
- Added `signature` (hash of `renderSignature` values) for content-aware equality instead of just count + last ID
- Added `renderSignature` computed property to `StreamingBlock` for efficient content hashing

### 6. Hasher-based toolRevision
Changed `toolRevision` in `StreamingMarkdownView` from string concatenation to `Hasher`. Avoids allocating a joined string on every frame during streaming.

### 7. Frozen-region tool filtering
Changed tool position adjustment from `map` (adjusts all) to `compactMap` (filters out tools at `pos <= frozenCharCount`). Prevents duplicate tool rendering in both frozen and tail regions.

## Cleanup

Removed during this pass:
- `isCompact` parameter threaded through `ConversationView` > `ChatMessageList` > `ObservedMessageBubble` > `MessageBubble` (declared but never read in any view body)
- All diagnostic `AppLogger.performanceInfo` logging added during debugging
- `debugSummary` on `StreamingBlock` (only consumer was removed logging)
- `debugSignature` on `ToolGroupView` (same)
- Tool call throttle in `ObservedMessageBubble` (string comparison overhead on every publish, could silently drop final tool state)

## Result

- Pills tappable everywhere on screen, including near input bar
- Pills tappable during and after streaming
- Sheet opens without heavy FPS drop (55+ sustained, previously caused layout thrashing)
- Stable view identity during streaming (no gesture recognizer destruction)
- Fewer unnecessary ToolGroupView re-renders via Equatable
