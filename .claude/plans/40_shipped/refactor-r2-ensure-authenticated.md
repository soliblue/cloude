---
title: "Refactor R2: Extract ensureAuthenticated() helper"
description: "Extracted repeated authentication guard pattern into a shared ensureAuthenticated() helper."
created_at: 2026-02-07
tags: ["refactor", "connection"]
icon: lock.shield
build: 43
---


# Refactor R2: Extract ensureAuthenticated() helper {lock.shield}
## Status: Active

## Problem
13 public methods in `ConnectionManager+API.swift` all repeat:
```swift
if !isAuthenticated { reconnectIfNeeded() }
```

## Fix
Extract to `private func ensureAuthenticated()` and replace all 13 call sites.
