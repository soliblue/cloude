---
title: "Android Conversation Persistence"
description: "Persist conversations to disk so they survive app restarts."
created_at: 2026-03-28
tags: ["android", "storage"]
icon: externaldrive
build: 120
---
# Android Conversation Persistence {externaldrive}


## Desired Outcome
Save conversations as JSON files (matching iOS approach: one file per conversation in app's files directory). Load on startup, save after each message. Support multiple conversations.

**Files (iOS reference):** ConversationStore+Persistence.swift
