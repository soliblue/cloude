---
title: "Offline Cache for Memories & Plans"
description: "Cached memories and plans on iOS for offline access with instant display and background refresh."
created_at: 2026-03-01
tags: ["ui", "memory", "plans"]
icon: arrow.down.circle
build: 74
---


# Offline Cache for Memories & Plans {arrow.down.circle}
## Problem

Every time you tap the brain/clipboard icon, the iOS app sends a WebSocket request to the Mac agent. If offline, you see nothing. Even when online, there's a loading delay every time.

## Solution

Add `OfflineCacheService` to persist memories and plans as JSON files in the app's documents directory. Show cached data immediately on sheet open, then refresh from agent if connected.

## Implementation

1. **OfflineCacheService** — small dedicated service
   - `saveMemories(_ sections:)` / `loadMemories() -> [MemorySection]?`
   - `savePlans(_ stages:)` / `loadPlans() -> [String: [PlanItem]]?`
   - Cache path: `{documents}/cache/memories.json` and `plans.json`
   - Atomic writes (`.atomic` option)
   - Decode failure → delete corrupt file, return nil
   - Store timestamp with data for staleness indicator

2. **CloudeApp changes**
   - On sheet open: load from cache first → display immediately
   - If connected: also request fresh data from agent
   - On fresh data received: update display + save to cache
   - Show subtle "cached" indicator when displaying stale data

## Scope

- Single project (no multi-project cache needed yet)
- No schema versioning (simple delete-and-refetch on decode failure)
- No race condition handling (last write wins)
