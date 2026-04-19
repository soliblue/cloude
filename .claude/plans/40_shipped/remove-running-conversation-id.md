---
title: "Remove runningConversationId"
description: "Replace the single `runningConversationId` with multi-conversation-aware logic."
created_at: 2026-03-30
tags: ["refactor", "streaming"]
icon: arrow.triangle.branch
build: 120
---


# Remove runningConversationId
## Problem

`EnvironmentConnection.runningConversationId` tracks a single running conversation per environment. The relay always sends `conversationId` with every event, so the single-ID tracker is dead weight. Worse, `handleDisconnect` only flushes one conversation's output, orphaning others if multiple are streaming.

## Changes

1. **Delete** `runningConversationId` from `EnvironmentConnection.swift:29`
2. **`ConnectionManager+API.swift:16`** - remove the line that sets it (output is already reset and marked running on lines 18-19)
3. **`EnvironmentConnection+Handlers.swift:18`** (`ensureRunning`) - remove the line setting it, keep `out.isRunning = true`
4. **`EnvironmentConnection+Handlers.swift:31`** (`handleOutput`) - remove the dead `else if` fallback branch (relay always sends conversationId)
5. **`EnvironmentConnection+Handlers.swift:67`** (`handleStatus` idle) - remove `runningConversationId = nil`, keep the `isAnyRunning` check
6. **`EnvironmentConnection+MessageHandler.swift:69`** (`handleDisconnect`) - flush ALL running `conversationOutputs` instead of just one
7. **`EnvironmentConnection+MessageHandler.swift:90`** (`targetConversationId`) - remove fallback, return nil if no conversationId
8. **`ConnectionManager.swift:120`** (`handleForegroundTransition`) - check if any outputs are running via `mgr.isAnyRunning` instead of checking the single ID

## Rules

- No new properties. Use existing `conversationOutputs` to find running conversations.
- Keep `isAnyRunning` / `endBackgroundStreaming` logic intact.
