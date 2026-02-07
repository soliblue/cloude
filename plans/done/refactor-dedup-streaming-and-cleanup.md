# Refactor: Deduplicate Streaming Completion, Send/Queue, and Cleanup

## Status: Active

## Summary
Eliminate ~100 lines of duplicated code across streaming completion, send/queue, and queued message replay logic. Plus cleanup of unused imports and duplicated constants.

## Changes

### 1. Unify streaming completion + send/queue + queued replay
- Extract `ConversationOutput.finalizeMessage(in:store:)` or similar helper
- Extract `ConversationStore.sendOrQueue(message:to:connection:)` helper
- Extract shared queued message replay logic
- Deduplicate thumbnail encoding

**Files affected:**
- `ConversationView.swift` (handleCompletion, sendQueuedMessages)
- `HeartbeatSheet.swift` (handleChatCompletion, sendQueuedMessages, sendMessage)
- `HeartbeatChatView.swift` (handleChatCompletion, sendQueuedMessages)
- `MainChatView+Messaging.swift` (sendMessage, sendHeartbeatMessage)
- New: `ConversationStore+Messaging.swift` (shared helpers)

### 2. Heartbeat interval constant
- Move interval options to single static constant (on HeartbeatConfig or similar)
- Remove duplicates from HeartbeatSheet and MainChatView

### 3. Consolidate isMemoryCommand/isScript
- Move to a shared ToolCallInfo struct or ToolCall extension
- ToolCallLabel and ToolDetailSheet both use it

### 4. Remove unused imports
- UIKit from MainChatView+PageIndicator, MainChatView+Utilities, HeartbeatChatView
- Combine from MainChatView+PageIndicator, MainChatView+Heartbeat, MainChatView+Messaging, MainChatView+Utilities, ConversationView+Components
