# Android Conversation Polish {sparkles}
<!-- priority: 12 -->
<!-- tags: android, conversations, ux -->

> Conversation symbols and search grouping by directory.

## Desired Outcome
Polish conversation list and display to match iOS visual details.

## Sub-features

### 1. Conversation symbols
- iOS assigns a random SF Symbol to each conversation (43 symbols: ant, hare, tortoise, bird, fish, leaf, etc.)
- `Conversation.symbol` field already exists in Android model but is not displayed
- Display symbol next to conversation name in list and header
- Map SF Symbol names to Material Icons equivalents

### 2. Search grouping by working directory
- iOS groups conversation search results by working directory with section headers
- Android currently shows flat list
- Group filtered results by `workingDirectory`, show directory path as sticky header

## Related tickets
- Rename, fork, history sync, and name suggestions are in `android-conversation-lifecycle.md`

**Files (iOS reference):** Conversation.swift, MainChatView+SearchSheet.swift
**Files (Android):** ConversationListSheet.kt, Conversation.kt
