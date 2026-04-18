---
title: "Message Storage Migration"
description: "Migrated message storage from UserDefaults to file-backed JSONL per conversation."
created_at: 2026-02-05
tags: ["streaming"]
icon: externaldrive
build: 31
---


# Message Storage Migration {externaldrive}
Move message storage from UserDefaults to file-backed JSONL per conversation. Keep lightweight summary cache for quick lists. Migration from UserDefaults on first launch. Add message count/size caps with graceful pruning.

**Files:** `ProjectStore.swift`, `ProjectStore+Conversation.swift`
