---
title: "Refactor Tier 2: Deduplication"
description: "Reduced repeated patterns across stores and models."
created_at: 2026-02-07
tags: ["refactor"]
icon: arrow.triangle.merge
build: 43
---


# Refactor Tier 2: Deduplication {arrow.triangle.merge}
## Status: Active

## Scope
Reduce repeated patterns across stores and models.

## Tasks

### 1. UserDefaults Codable extension
- Same JSONEncoder/JSONDecoder pattern repeated 15+ times across 7 files
- Create extension with optional convenience + default-value overload
- Log decode errors in debug builds (per Codex recommendation)
- Files: ConversationStore, WindowManager, HeartbeatStore, ResponseStore, CloudeApp

### 2. Heartbeat display logic dedup
- ConversationStore.HeartbeatConfig and HeartbeatStore have identical computed properties (~35 lines)
- intervalDisplayText, nextHeartbeatAt, lastTriggeredDisplayText, nextHeartbeatDisplayText
- Single source of truth: keep on HeartbeatConfig, remove from HeartbeatStore
