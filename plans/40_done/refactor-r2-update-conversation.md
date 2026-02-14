# Refactor R2: Extract updateConversation() helper
<!-- priority: 10 -->
<!-- tags: conversations, refactor -->
<!-- build: 56 -->

## Status: Active

## Problem
~15 methods in `ConversationStore+Operations.swift` repeat:
```swift
guard let idx = conversations.firstIndex(where: { $0.id == id }) else { return }
conversations[idx].property = newValue
if currentConversation?.id == id { currentConversation = conversations[idx] }
save()
```

## Fix
Extract to closure-based helper:
```swift
private func updateConversation(_ id: UUID, mutation: (inout Conversation) -> Void)
```
