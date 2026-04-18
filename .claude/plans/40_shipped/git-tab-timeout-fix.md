---
title: "Git Tab Timeout Fix"
description: "Added 10-second timeout on git status requests to prevent infinite loading on stale state."
created_at: 2026-03-13
tags: ["git", "connection"]
icon: clock.badge.exclamationmark
build: 86
---


# Git Tab Timeout Fix {clock.badge.exclamationmark}
## Problem
Git tab intermittently fails to load - stays on loading spinner forever. Root cause: the git status request queue has no timeout, so if a response never arrives (server busy, connection hiccup), `gitStatusInFlightPath` stays set and blocks all future requests.

## Changes
- **EnvironmentConnection.swift**: Added `gitStatusTimeoutTask` property
- **EnvironmentConnection+MessageHandler.swift**: 10-second timeout on in-flight git status requests - clears stale state and processes next queued request
- **EnvironmentConnection+FileHandlers.swift**: Cancel timeout when response arrives
- **GitChangesView.swift**: Force-clear stale in-flight state on `loadStatus()` so tab switches and pull-to-refresh always work

## Test
1. Open git tab - should load normally
2. Switch away and back rapidly - should still load
3. Open git tab while agent is streaming - should load (or timeout and retry)
4. Pull to refresh after a stall - should recover
