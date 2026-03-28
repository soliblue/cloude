# Android Conversation Persistence {externaldrive}
<!-- priority: 5 -->
<!-- tags: android, storage -->

> Persist conversations to disk so they survive app restarts.

## Desired Outcome
Save conversations as JSON files (matching iOS approach: one file per conversation in app's files directory). Load on startup, save after each message. Support multiple conversations.

**Files (iOS reference):** ConversationStore+Persistence.swift
