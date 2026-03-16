# Fix scroll lag when scrolling back down mid-stream

During streaming, when the user scrolls up and then scrolls back down with their finger, the scroll feels laggy. When not streaming, scrolling is perfectly smooth.

## Root Cause

The streaming bubble grows with each token, causing ScrollView content size to change. During finger-drag scrolling, the scroll position and content size are both changing simultaneously, creating layout thrashing. The CADisplayLink text drain fires every frame, each frame changes content height, each height change triggers a scroll layout pass while the gesture is also driving layout.

## What We Tried (no noticeable improvement)

1. **`.equatable()` on `MessageBubble`** - added Equatable conformance so SwiftUI skips body recomputation for unchanged historical bubbles. Didn't help because the bottleneck isn't view diffing of old bubbles, it's the layout pass from content size changes.

2. **Throttled `parent?.objectWillChange.send()` to ~15Hz** - reduced how often ConnectionManager broadcasts during streaming. Didn't help because ConversationOutput's own @Published text still fires at 60Hz, and the layout thrashing comes from the streaming bubble itself growing.

## Ideas to Explore

1. **Pause text drain while user is scrolling** - if `userHasScrolled` is true and finger is actively dragging, stop the CADisplayLink drain. Buffer tokens and flush when the gesture ends. Scrolling becomes instant because nothing is changing content size. Text catches up quickly after finger lifts.

2. **Detach streaming bubble from ScrollView** - render the streaming bubble as a fixed overlay at the bottom instead of inside the LazyVStack. Only insert it into the scroll when streaming completes. Eliminates content-size-driven layout during streaming entirely.

3. **Pre-allocate streaming bubble height** - estimate a generous height for the streaming area so growth doesn't cause content size jumps. Less elegant, might cause visual gaps.

4. **Migrate to @Observable (iOS 17)** - property-level tracking instead of object-level would eliminate most cascading invalidation. Larger migration.

## Files
- `Cloude/Cloude/Services/ConnectionManager+ConversationOutput.swift` - CADisplayLink drain, text updates
- `Cloude/Cloude/UI/ConversationView+Components.swift` - LazyVStack, messageListSection, scroll handling
- `Cloude/Cloude/UI/MessageBubble.swift` - bubble rendering
- `Cloude/Cloude/UI/StreamingMarkdownView.swift` - markdown parsing per update
