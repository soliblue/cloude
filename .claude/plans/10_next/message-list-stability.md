---
title: Message list structural instability
priority: critical
---

# Message list structural instability

## The problem

The message list is brittle. It has been broken in different ways across dozens of sessions and builds. Every fix creates a new symptom because the root cause is architectural, not a missing modifier or wrong flag.

## Symptoms (recurring, across many builds)

- Messages disappear and reappear when keyboard opens
- Messages disappear when typing in the input bar
- Compacting indicator slides from top to bottom instead of appearing in place
- Scroll position jumps on content changes
- Message content gets cut off until the user touches the screen
- The whole list vanishes briefly on any state change (send, receive, reconnect)
- FPS drops when switching away from LazyVStack

These are not separate bugs. They are the same bug wearing different hats.

## Root cause

The message list's **view identity is unstable**. Three structural decisions make it fragile:

### 1. Conditional existence of the scroll view

`ConversationView+Components.swift:75`:
```swift
if !showEmptyState || !hasRequiredDependencies {
    scrollableContent
}
```

When `showEmptyState` flips to true (even for one frame), SwiftUI removes `scrollableContent` from the view tree entirely. The LazyVStack, all recycled cells, and scroll position are destroyed. When it flips back, everything is rebuilt from scratch. This causes the "messages disappear and reappear" flash.

`showEmptyState` depends on `messages.isEmpty && isOutputEmpty && !isStreaming` which can briefly all be true during state transitions (reconnect, compact, send).

### 2. if/else view switching in MessageBubble

`MessageBubble.swift:100-120`:
```swift
Group {
    if isSlashCommand { ... }
    else if message.isUser { ... }
    else if isLive && isCompacting { CompactingIndicator() }
    else if hasToolCalls { StreamingMarkdownView(...) }
    else if !effectiveText.isEmpty { StreamingMarkdownView(...) }
    else if isLive { MessageBubbleLoadingView() }
}
```

Each branch is a structurally different view. When state changes (e.g. isCompacting flips, or text goes from empty to non-empty), SwiftUI doesn't update the existing view, it removes one and inserts another. This causes content to animate in from wrong positions instead of appearing in place.

### 3. ConversationOutput @Published fan-out

Every `@Published` property on `ConversationOutput` (text, isRunning, isCompacting, toolCalls, etc.) triggers `objectWillChange` on the parent `ConnectionManager`, which re-renders every view observing it. This means typing, streaming, compacting, and other unrelated state changes all cause the message list to re-evaluate its conditionals.

## What NOT to do

- Don't add `.transaction { $0.animation = nil }` - this suppresses ALL animations and makes the list feel broken in different ways
- Don't switch LazyVStack to VStack - kills FPS with many messages
- Don't add padding/spacers to compensate for layout miscalculations - treats symptoms
- Don't add GeometryReader to track viewport - adds more state updates during transitions

## Direction

- Replace conditional view removal with opacity/visibility (keep views in the tree, just hide them)
- Use stable view identity in the message bubble (avoid structural if/else for content that changes during a message's lifetime)
- Consider making ConversationOutput observation more surgical so unrelated publishes don't cascade

## Files

- `/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Features/Conversation/Views/ConversationView+Components.swift`
- `/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Features/Conversation/Views/ConversationView+MessageScroll.swift`
- `/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Features/Conversation/Views/MessageBubble.swift`
- `/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Features/Conversation/Views/MessageBubble+Components.swift`
- `/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Shared/Services/ConnectionManager+ConversationOutput.swift`
