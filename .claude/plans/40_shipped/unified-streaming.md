---
title: "Unified Streaming"
description: "Streaming output and saved messages use duplicate rendering paths. When a response finishes, the streaming view disappears for a frame before the saved message appears. Fix: stream directly into a MessageBubble."
created_at: 2026-03-22
tags: ["streaming", "ui", "bug"]
icon: bubble.left.and.text.bubble.right
build: 103
---


# Unified Streaming {bubble.left.and.text.bubble.right}
## Problem

Two separate rendering paths do the same thing:

```
ForEach(messages) { MessageBubble(message) }           // saved
if hasOutput { StreamingInterleavedOutput(output) }     // live
```

Both use `StreamingMarkdownView` + `InlineToolPill`. `StreamingInterleavedOutput` duplicates the interleaving logic that `StreamingMarkdownView.parseWithToolCalls` already handles.

When done: `addMessage()` + `output.reset()` → flicker (old disappears before new renders).

## Fix

Use `MessageBubble` for everything. When streaming starts, insert an empty `ChatMessage` into the messages array. That bubble reads from `ConversationOutput` while live, then gets its final text written in-place when done. Same bubble, no handoff.

The only difference between a live and saved bubble: live reads `output.text` instead of `message.text`, and passes `isComplete: false` to `StreamingMarkdownView` (disables header collapse chevrons mid-stream).

## Changes

### 1. `ConnectionManager+ConversationOutput.swift`

Add one property:

```swift
var liveMessageId: UUID?
```

Clear it in `reset()`:

```swift
func reset() {
    ...
    liveMessageId = nil
}
```

### 2. `ConversationStore+Messaging.swift`

Add `insertLiveMessage`:

```swift
func insertLiveMessage(into conversation: Conversation) -> UUID {
    let message = ChatMessage(isUser: false, text: "")
    addMessage(message, to: conversation)
    return message.id
}
```

Rewrite `finalizeStreamingMessage` to update in-place:

```swift
func finalizeStreamingMessage(output: ConversationOutput, conversation: Conversation) {
    if let liveId = output.liveMessageId {
        let freshConv = self.conversation(withId: conversation.id) ?? conversation
        if output.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            removeMessage(liveId, from: freshConv)
        } else {
            let rawText = output.text
            let trimmedText = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
            let leadingTrimmed = rawText.count - rawText.drop(while: { $0.isWhitespace || $0.isNewline }).count
            let adjustedToolCalls = output.toolCalls.map { tool in
                var adjusted = tool
                if leadingTrimmed > 0, let pos = adjusted.textPosition {
                    adjusted.textPosition = max(0, pos - leadingTrimmed)
                }
                if adjusted.state == .executing { adjusted.state = .complete }
                return adjusted
            }
            // build teamSummary same as today...
            updateMessage(liveId, in: freshConv) { msg in
                msg.text = trimmedText
                msg.toolCalls = adjustedToolCalls
                msg.durationMs = output.runStats?.durationMs
                msg.costUsd = output.runStats?.costUsd
                msg.serverUUID = output.messageUUID
                msg.model = output.runStats?.model
                msg.teamSummary = teamSummary
            }
        }
    } else {
        // fallback: current insert behavior for edge cases
        // (existing code, unchanged)
    }
    output.reset()
}
```

### 3. `EnvironmentConnection+Handlers.swift`

Add shared helper to ensure the live message exists. Streams can start with tool calls or compaction before any text arrives, so call from **every** handler that produces visible output:

```swift
private func ensureLiveMessage(_ mgr: ConnectionManager, convId: UUID) {
    let out = mgr.output(for: convId)
    if out.liveMessageId == nil {
        mgr.events.send(.streamingStarted(conversationId: convId))
    }
}
```

In `handleOutput`, emit event when `isRunning` transitions:

```swift
func handleOutput(_ mgr: ConnectionManager, text: String, conversationId: String?) {
    if let convIdStr = conversationId, let convId = UUID(uuidString: convIdStr) {
        let out = mgr.output(for: convId)
        out.appendText(text)
        if !out.isRunning {
            out.isRunning = true
            runningConversationId = convId
        }
        ensureLiveMessage(mgr, convId: convId)
    } else if let convId = runningConversationId {
        mgr.output(for: convId).appendText(text)
    }
}
```

Also call `ensureLiveMessage` in `handleToolCall` and `handleStatus(.compacting)` so streams that begin with tools or compaction (before any text) still get a live bubble.

### 4. `ConnectionEvent.swift`

Add one case:

```swift
case streamingStarted(conversationId: UUID)
```

### 5. `CloudeApp+EventHandling.swift`

Handle `.streamingStarted` to insert the live message:

```swift
case .streamingStarted(let convId):
    let output = connection.output(for: convId)
    if output.liveMessageId == nil, let conv = conversationStore.findConversation(withId: convId) {
        output.liveMessageId = conversationStore.insertLiveMessage(into: conv)
    }
```

Update `.disconnect` to use live message:

```swift
case .disconnect(let convId, let output):
    if let liveId = output.liveMessageId, let conv = conversationStore.findConversation(withId: convId) {
        if !output.text.isEmpty {
            updateMessage(liveId, in: conv) { msg in
                msg.text = output.text.trimmingCharacters(in: .whitespacesAndNewlines)
                msg.toolCalls = output.toolCalls
                msg.wasInterrupted = true
            }
            // interruptedSession logic stays the same but uses liveId
        } else {
            conversationStore.removeMessage(liveId, from: conv)
        }
        output.reset()
    } else {
        // fallback: current behavior
    }
```

### 6. `MessageBubble.swift`

Add one optional prop:

```swift
var liveOutput: ConversationOutput? = nil
```

Add computed properties:

```swift
private var isLive: Bool { liveOutput != nil }
private var effectiveText: String { liveOutput?.text ?? message.text }
private var effectiveToolCalls: [ToolCall] { liveOutput?.toolCalls ?? message.toolCalls }
```

Update `messageContent` to use them:

```swift
// BEFORE:
} else if hasToolCalls {
    StreamingMarkdownView(text: message.text, toolCalls: message.toolCalls)
} else if !message.text.isEmpty {
    StreamingMarkdownView(text: message.text)
}

// AFTER:
} else if isLive && (liveOutput?.isCompacting ?? false) {
    CompactingIndicator()
} else if !effectiveToolCalls.filter({ $0.parentToolId == nil }).isEmpty {
    StreamingMarkdownView(text: effectiveText, toolCalls: effectiveToolCalls, isComplete: !isLive)
} else if !effectiveText.isEmpty {
    StreamingMarkdownView(text: effectiveText, isComplete: !isLive)
} else if isLive {
    SisyphusLoadingView()
}
```

Update `hasToolCalls` and `hasInteractiveWidgets` to use `effectiveToolCalls`.

Update `messageFooter`: when `isLive`, show live `RunStatsView` from `liveOutput?.runStats` instead of saved stats. Suppress stats when `isCompact` (pass `isCompact` through to MessageBubble).

Update text selection sheet and long press copy to use `effectiveText` instead of `message.text` (otherwise copying mid-stream returns `""`).

### 7. `MessageBubble+LiveWrapper.swift` (NEW, ~15 lines)

```swift
import SwiftUI

struct ObservedMessageBubble: View {
    let message: ChatMessage
    @ObservedObject var output: ConversationOutput
    var skills: [Skill] = []
    var onRefresh: (() -> Void)?
    var onToggleCollapse: (() -> Void)?
    var isRefreshing: Bool = false

    var body: some View {
        MessageBubble(
            message: message,
            skills: skills,
            liveOutput: output.liveMessageId == message.id ? output : nil,
            onRefresh: onRefresh,
            onToggleCollapse: onToggleCollapse,
            isRefreshing: isRefreshing
        )
    }
}
```

Needed because `MessageBubble` is a struct with value types. Only the live message needs `@ObservedObject` on `ConversationOutput`. Saved messages skip the observation overhead entirely.

### 8. `ConversationView+MessageScroll.swift`

Replace the three sections with one:

```swift
// BEFORE:
messageListSection(viewportHeight: scrollViewportHeight)
if agentState == .running && currentOutput.isEmpty && currentToolCalls.isEmpty && currentRunStats == nil && !isCompacting {
    sisyphusSection
}
if !currentToolCalls.isEmpty || !currentOutput.isEmpty || currentRunStats != nil || isCompacting {
    streamingSection
}

// AFTER:
messageListSection(viewportHeight: scrollViewportHeight)
```

Update `messageListSection` to use `ObservedMessageBubble` for the live message:

```swift
func messageListSection(viewportHeight: CGFloat) -> some View {
    ForEach(messages) { message in
        if let output = conversationOutput, output.liveMessageId == message.id {
            ObservedMessageBubble(
                message: message,
                output: output,
                skills: connection?.skills ?? [],
                onToggleCollapse: message.isUser ? nil : { toggleCollapse(message) }
            )
            .id("\(message.id)-\(message.isQueued)")
        } else {
            MessageBubble(
                message: message,
                skills: connection?.skills ?? [],
                onRefresh: message.isUser ? nil : { refreshMessage(message) },
                onToggleCollapse: message.isUser ? nil : { toggleCollapse(message) },
                isRefreshing: refreshingMessageId == message.id
            )
            .readingProgress(...)
            .id("\(message.id)-\(message.isQueued)")
        }
    }
}
```

Delete `sisyphusSection`, `streamingSection`, `streamingId`.

### 9. `ConversationView+Components.swift` (ChatMessageList)

Remove props that are no longer needed:

```swift
// DELETE:
let currentOutput: String
let currentToolCalls: [ToolCall]
let currentRunStats: (durationMs: Int, costUsd: Double, model: String?)?
var isCompacting: Bool = false

// KEEP:
var conversationOutput: ConversationOutput?
let agentState: AgentState
```

Update `showLoadingIndicator` and `showEmptyState` - replace `currentOutput.isEmpty` with `conversationOutput?.text.isEmpty ?? true`.

### 10. `ConversationView.swift`

Update `handleCompletion()` guard to not require non-empty text (empty placeholder cleanup needs to run):

```swift
// BEFORE:
guard let output = convOutput, !output.text.isEmpty, !output.isRunning else { return }

// AFTER:
guard let output = convOutput, !output.isRunning else { return }
```

**Copy/select**: `TextSelectionSheet` and `BubbleLongPressOverlay` currently use `message.text`. Update them to accept `effectiveText` so copying from a live bubble gets the actual streamed text, not `""`.

**Compact mode stats**: Currently `ConversationView` passes `isCompact ? nil : output?.runStats` to suppress stats in compact mode. With the new approach, pass `isCompact` to `MessageBubble`/`ObservedMessageBubble` and suppress stats there when `isCompact && isLive`.

Simplify `ChatMessageList` construction:

```swift
// REMOVE these lines:
currentOutput: output?.text ?? "",
currentToolCalls: output?.toolCalls ?? [],
currentRunStats: isCompact ? nil : output?.runStats,
isCompacting: output?.isCompacting ?? false,
```

Add `.onAppear` safety check after the `.onChange`:

```swift
.onAppear {
    if let output = convOutput, output.isRunning, output.liveMessageId == nil {
        if let conv = effectiveConversation {
            output.liveMessageId = store.insertLiveMessage(into: conv)
        }
    }
}
```

### 11. `MainChatView+HeartbeatChat.swift`

Same simplification: remove `currentOutput`, `currentToolCalls`, `currentRunStats` from ChatMessageList init. The heartbeat's `handleChatCompletion()` already calls `finalizeStreamingMessage` which now handles in-place updates.

### 12. Cleanup (delete)

| Delete | From |
|--------|------|
| `StreamingInterleavedOutput` | `MessageBubble+StreamingOutput.swift` |
| `StreamingOutput` | `MessageBubble+StreamingOutput.swift` |
| `StreamingPlaceholder` | `MessageBubble+StreamingOutput.swift` |
| `StreamingSegment` enum | `MessageBubble+StreamingOutput.swift` |
| `StreamingContentObserver` | `ConversationView+StreamingContent.swift` |

Move before deleting:
- `CompactingIndicator` → `MessageBubble+Components.swift`
- `QueuedBubble` → `ConversationView+MessageScroll.swift`

Then delete both files:
- `MessageBubble+StreamingOutput.swift`
- `ConversationView+StreamingContent.swift`

## Edge Cases

- **View not mounted when streaming starts**: Handled by `.streamingStarted` event at app level, plus `.onAppear` safety check
- **Empty response (canceled)**: `finalizeStreamingMessage` removes the empty placeholder
- **Disconnect mid-stream**: `.disconnect` updates the live message in place with `wasInterrupted = true`
- **History sync during streaming**: `replaceMessages` drops the live placeholder. In the `.historySync` handler in `CloudeApp+EventHandling`, after `replaceMessages`, check if `output.isRunning` and `liveMessageId != nil` - if so, re-insert a live message and update `liveMessageId`
- **Multiple rapid responses**: `reset()` clears `liveMessageId`, each response gets a fresh live message

## Tasks

- [x] Add `liveMessageId: UUID?` to `ConversationOutput`, clear in `reset()`
- [x] Add `insertLiveMessage(into:)` to `ConversationStore+Messaging`
- [x] Rewrite `finalizeStreamingMessage` to update in-place via `liveMessageId`
- [x] Add `case streamingStarted(conversationId:)` to `ConnectionEvent`
- [x] Add `ensureLiveMessage` helper, call from `handleOutput`, `handleToolCall`, and `handleStatus(.compacting)`
- [x] Handle `.streamingStarted` in `CloudeApp+EventHandling` (insert live message)
- [x] Update `.disconnect` handler to use live message
- [x] Add `liveOutput` prop + `effectiveText`/`effectiveToolCalls` to `MessageBubble`
- [x] Update `messageContent` to use effective values + sisyphus/compacting states
- [x] Create `MessageBubble+LiveWrapper.swift` with `ObservedMessageBubble`
- [x] Update `messageListSection` to use `ObservedMessageBubble` for live message
- [x] Remove `streamingSection` and `sisyphusSection` from scroll content
- [x] Remove `currentOutput`/`currentToolCalls`/`currentRunStats`/`isCompacting` from `ChatMessageList`
- [x] Simplify `ConversationView` and `HeartbeatChat` ChatMessageList construction
- [x] Add `.onAppear` safety check in `ConversationView`
- [x] Update `handleCompletion()` guard to allow empty-text finalization (placeholder cleanup)
- [x] Update copy/select (`TextSelectionSheet`, `BubbleLongPressOverlay`) to use `effectiveText`
- [x] Pass `isCompact` to `MessageBubble`/`ObservedMessageBubble`, suppress live stats when compact
- [x] Re-insert live message after `.historySync` `replaceMessages` if still streaming
- [x] Move `CompactingIndicator` and `QueuedBubble`, delete dead files

## Verification

1. Send a message, verify streaming appears smoothly in a message bubble
2. Response completes with no flicker, run stats appear in the same bubble
3. Interrupt mid-stream (disconnect) - bubble stays with "interrupted" state
4. Switch away mid-stream, return - no duplicate messages
5. Heartbeat conversations work
6. Tool calls interleaved with text render correctly during and after streaming
7. Compacting indicator shows inside the bubble
