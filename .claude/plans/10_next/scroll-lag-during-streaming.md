# Fix scroll lag when scrolling back down mid-stream

During streaming, when the user scrolls up and then scrolls back down with their finger, the scroll feels laggy. Confirmed not related to the scroll-to-bottom button — it's purely finger-drag scroll.

## Root Cause (confirmed by Codex)

Three compounding issues:

1. **`ConnectionManager.objectWillChange` broadcast on every token** — `ConversationOutput.text` calls `parent?.objectWillChange.send()` on every didSet. This invalidates the entire `ConversationView` subtree (including `ScrollView` + `LazyVStack`) on every token, not just the streaming subview.

2. **`readingProgress` geometry churn** — every historical `MessageBubble` has reading progress geometry/preference tracking. During a drag gesture, geometry updates are frequent. Combined with per-token layout invalidation, this compounds the jank significantly.

3. **Lazy cell materialization** — as the user scrolls back down, `LazyVStack` materializes cells that were dequeued, while layout is simultaneously being invalidated from streaming. The two operations fight each other.

## Proposed Fixes (in priority order per Codex)

1. **Stop broadcasting through `ConnectionManager.objectWillChange`** — observe `ConversationOutput` directly in streaming subviews so only those refresh on tokens, not the whole tree. This is the highest-impact fix.

2. **Throttle UI text commits** — instead of committing on every display tick/token, batch at ~20-30 Hz. Reduces invalidation frequency drastically.

3. **Scope `readingProgress` geometry** — apply only to visible/active candidate messages, not every message in the list.

4. **`.equatable()` on `MessageBubble`** — add `Equatable` conformance so SwiftUI skips body recomputation for unchanged historical cells. Useful but secondary — doesn't fix parent layout invalidation or geometry churn.

## Original hypothesis (partially correct)
The lazy materialization + streaming invalidation fight is real, but the root driver is the `objectWillChange` broadcast making the whole tree dirty, not just the streaming section.

## Files
- `/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Services/ConnectionManager+ConversationOutput.swift` — objectWillChange broadcast, text throttling
- `/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/UI/ConversationView+Components.swift` — LazyVStack, messageListSection, readingProgress usage
- `/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/UI/MessageBubble.swift` — Equatable conformance
- `/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/UI/ConversationView+ReadingProgress.swift` — geometry work per bubble
