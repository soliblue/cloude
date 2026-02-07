# Refactor R2: Extract ensureAuthenticated() helper

## Status: Active

## Problem
13 public methods in `ConnectionManager+API.swift` all repeat:
```swift
if !isAuthenticated { reconnectIfNeeded() }
```

## Fix
Extract to `private func ensureAuthenticated()` and replace all 13 call sites.
