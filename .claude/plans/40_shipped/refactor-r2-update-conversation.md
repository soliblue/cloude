---
title: "Refactor R2: Extract updateConversation() helper"
description: "Extracted repeated conversation update pattern into a shared updateConversation() helper."
created_at: 2026-02-07
tags: ["refactor"]
icon: arrow.triangle.2.circlepath
build: 43
---


# Refactor R2: Extract updateConversation() helper
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
