# Persist Model + Effort Per Conversation
<!-- build: 96 -->

Model and effort selections reset after app restart or window close. The entire infrastructure already exists -- it just isn't being called.

## What already exists
- `Conversation.defaultModel: ModelSelection?` and `Conversation.defaultEffort: EffortLevel?`
- `ConversationStore.setDefaultModel(_:model:)` and `ConversationStore.setDefaultEffort(_:effort:)`
- `MainChatView` already reads these back on conversation load (lines 169-170, 185-186)
- `MainChatView+Messaging.swift` already falls back to `conv.defaultModel`/`conv.defaultEffort` when sending

## What's missing
`GlobalInputBar` (or wherever model/effort selection happens) never calls `setDefaultModel`/`setDefaultEffort` when the user changes them.

## Fix
When user changes model or effort in the input bar, call the appropriate setter on `ConversationStore` with the current conversation. One `onChange` (or equivalent) per control.

## Files
- `Cloude/UI/GlobalInputBar.swift` -- add onChange handlers that call store setters
- Possibly `Cloude/UI/MainChatView.swift` -- if model/effort state lives there instead

## Notes
No schema changes, no new types, no new functions needed. Pure wiring.
