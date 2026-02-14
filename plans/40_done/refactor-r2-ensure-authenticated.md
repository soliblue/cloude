# Refactor R2: Extract ensureAuthenticated() helper
<!-- priority: 10 -->
<!-- tags: refactor -->
<!-- build: 56 -->

## Status: Active

## Problem
13 public methods in `ConnectionManager+API.swift` all repeat:
```swift
if !isAuthenticated { reconnectIfNeeded() }
```

## Fix
Extract to `private func ensureAuthenticated()` and replace all 13 call sites.
