---
title: "Environment Chat Ownership"
description: "Added environment ownership to conversations, preventing cross-environment message sends."
created_at: 2026-03-08
tags: ["env", "connection"]
icon: lock.laptopcomputer
build: 82
---

# Environment Chat Ownership {lock.laptopcomputer}
conversations should track which environment they belong to, preventing users from sending messages when connected to a different environment.

## Changes

### 1. Conversation model - add environmentId
- `Conversation.swift`: Add `var environmentId: UUID?` field
- Set it when a conversation first receives a message or is created in an environment
- Existing conversations with no environmentId are "unbound" (work anywhere)

### 2. Disable send button when environment mismatches
- `GlobalInputBar+ActionButton.swift`: Check if conversation's environmentId matches `environmentStore.activeEnvironmentId`
- If mismatched and conversation has an environmentId: disable send button, show muted state
- Unbound conversations (nil environmentId) always allow sending

### 3. Show environment icon in WindowEditSheet
- `WindowEditSheet.swift` or `WindowEditSheet+Form.swift`: Show the environment symbol next to the conversation
- Pull from `environmentStore` using conversation's environmentId
- If unbound, show nothing or a generic icon

### 4. Set environmentId on chat
- `ConnectionManager+MessageHandler.swift` or wherever conversations get created/first-messaged: stamp `environmentStore.activeEnvironmentId` onto the conversation if it doesn't have one yet
