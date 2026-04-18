---
title: "Android Conversation Management"
description: "Full conversation lifecycle: create, rename, delete, fork, history sync."
created_at: 2026-03-28
tags: ["android", "conversations"]
icon: bubble.left.and.bubble.right
build: 120
---
# Android Conversation Management {bubble.left.and.bubble.right}


## Desired Outcome
Conversation list in drawer or sheet. Create new conversations. Rename with auto-suggest (`suggestName`). Delete conversations. Sync history with agent (`syncHistory`). Conversation info panel (session ID, working directory, cost). Resume interrupted sessions (`requestMissedResponse`).

**Files (iOS reference):** ConversationStore.swift (+Messages, +Messaging, +Operations, +Persistence), ConversationView.swift (+Components, +EmptyState, +MessageScroll)
