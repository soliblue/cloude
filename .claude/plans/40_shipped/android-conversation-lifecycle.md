---
title: "Android Conversation Lifecycle"
description: "Rename, fork, history sync, and auto-naming for conversations."
created_at: 2026-03-29
tags: ["android", "conversations"]
build: 120
icon: arrow.triangle.2.circlepath
---
# Android Conversation Lifecycle {arrow.triangle.2.circlepath}


## Context
The conversation management ticket (android-conversation-management, done) covered create, delete, list, and search. But several lifecycle features are missing.

## Missing sub-features

### 1. Rename conversations
- iOS allows tapping the conversation title in the header to edit it inline
- Android has no rename UI - name is set at creation and never changes
- Add: tap conversation name in header to show rename dialog, or inline editable text field
- Update `ConversationStore` with rename operation

### 2. Apply server name suggestions
- Server sends `ServerMessage.NameSuggestion` with AI-generated names
- Message type is already parsed in Android but the suggestion is never applied
- Wire it in `ChatViewModel` or message handler: when `NameSuggestion` arrives, update the conversation name
- Only apply if the conversation still has its random default name (don't overwrite user renames)

### 3. Fork conversation
- iOS allows forking a conversation (creating a new one with messages up to a certain point)
- Useful for branching from a specific message
- Android has no fork UI or logic
- Add: long-press on a message to show "Fork from here" option, creates new conversation with messages up to that point

### 4. History sync
- `ClientMessage.SyncHistory` and `ServerMessage.SyncHistory` types exist in the protocol
- iOS uses this to sync conversation history from the agent
- Android parses the message type but doesn't wire it to UI
- Add: sync button or auto-sync on conversation load to pull missed messages

## Implementation notes
Sub-features 1-2 are quick wins. Sub-feature 3 is medium effort. Sub-feature 4 needs protocol understanding. Name suggestions (#2) is also referenced in android-conversation-polish but the rename and fork features are distinct enough to warrant this ticket.

**Files (iOS reference):** ConversationStore+Operations.swift, ConversationView+Components.swift
**Files (Android):** ChatViewModel.kt, ConversationStore.kt, ConversationListSheet.kt
