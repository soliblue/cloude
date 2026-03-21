# Fix Scroll Jump on Streaming Finish & Pending Message Replay

## Problem

Two scroll jump bugs with the same root cause: SwiftUI view identity breaks during content transitions.

### Bug 1: Streaming finish
When streaming finishes, the screen goes empty and the user has to scroll up to find the content. The streaming content (rendered by `StreamingContentObserver` with ID `"streaming-{convId}"`) gets destroyed, and a new `MessageBubble` (with ID `"{messageId}-false"`) appears in a different section. SwiftUI can't match these IDs, so `.defaultScrollAnchor(.bottom)` re-anchors to a momentarily empty layout.

**Flow today:**
1. During streaming: `streamingSection` renders `StreamingContentObserver` from `ConversationOutput`
2. `finalizeStreamingMessage()` creates a brand new `ChatMessage(id: UUID(), ...)`, adds to `messages` array
3. `output.reset()` clears streaming state
4. `streamingSection` disappears, `messageListSection` renders the same content via `MessageBubble`
5. Different view, different ID, different section = scroll position lost

### Bug 2: Pending message replay
Queued messages have SwiftUI ID `"\(uuid)-true"`, then when replayed the same message moves to `messages` array with ID `"\(uuid)-false"`. The `-isQueued` suffix causes an unnecessary ID change.

**Flow today:**
1. Message created with `isQueued: true`, added to `pendingMessages` array
2. `queuedMessagesSection` renders it with `.id("\(message.id)-true")`
3. On replay: `popPendingMessages` moves it to `messages` array with `isQueued = false`
4. `messageListSection` renders it with `.id("\(message.id)-false")`
5. Different ID = SwiftUI sees old view disappear and new view appear

## Root Cause

The core issue is that the same content gets rendered by different views with different identities during state transitions. SwiftUI treats these as completely different content, causing the scroll view to lose position.

Codex (GPT-5.4) confirmed: "The bug is not SwiftUI re-rendering in the abstract, it's identity and structural replacement."

## Desired Outcome

No scroll jump when streaming finishes or when pending messages are replayed. Content stays in place visually during all transitions.

## Approach

### Unified message row (recommended by both us and Codex)

Instead of having a separate `streamingSection` that swaps to a `MessageBubble`, use a single view identity for each assistant turn:

1. When streaming starts, create a draft `ChatMessage` with a stable ID in the `messages` array
2. Stream text/toolCalls/runStats into that same row (via `ConversationOutput` or direct updates)
3. On completion, mark it finalized instead of creating a new message
4. The row stays mounted with the same ID throughout. Chrome (run stats, action menu, collapse) appears when `isRunning` goes false
5. `reset()` only happens when the next streaming message starts, not at finalization

Key constraints from Codex:
- Same view type but different `.id` won't fix it
- Same `.id` but moving between sections won't fix it
- Keeping the row but reinserting through `if` branches in different containers won't fix it
- The row must stay in the **same container** with the **same identity** throughout

### Pending message fix (simple)

Drop `-isQueued` from the SwiftUI ID:
```swift
// before
.id("\(message.id)-\(message.isQueued)")
// after
.id(message.id.uuidString)
```
The `-isQueued` suffix is unnecessary since `pendingMessages` and `messages` are separate arrays rendered by separate `ForEach` loops. They never coexist with the same message.

## Stale State Risks (if deferring reset)

If `ConversationOutput` isn't reset at finalization, watch for:
- Team banner/orbs read `teamName` and `teammates` from output (`ConversationView.swift`)
- `streamingSection` visibility is driven by non-empty output (`ConversationView+MessageScroll.swift`)
- `sendChat()` assumes reset happens before new run starts (`ConnectionManager+API.swift`)

Need a clear contract: "idle but displaying committed snapshot" vs "actively streaming".

## Files

- `ConversationView+Components.swift` (or `ConversationView+MessageScroll.swift`) - scroll view, section rendering, message IDs
- `ConversationView+StreamingContent.swift` - `StreamingContentObserver`
- `ConversationView.swift` - `handleCompletion()`, finalization trigger
- `ConversationStore+Messaging.swift` - `finalizeStreamingMessage()`, `replayQueuedMessages()`
- `ConnectionManager+ConversationOutput.swift` - `ConversationOutput`, `reset()`
- `ConnectionManager+API.swift` - `sendChat()` calls `reset()` before new run
- `MessageBubble.swift` - committed message rendering
- `StreamingMarkdownView.swift` - collapsible headers (minor: chevron appearance on `isComplete` flip adds small layout shift)

## Open Questions

- Should the draft `ChatMessage` be persisted to disk during streaming, or only on finalization?
- How to handle `ConversationOutput`'s display link text draining with the unified row model?
- Should `MessageBubble` accept a `ConversationOutput` directly, or should we update the `ChatMessage` in-place during streaming?
