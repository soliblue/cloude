---
title: "Connection Toggle Toolbar Button"
description: "Added connection toggle button to main toolbar with red/green power icon for disconnect/reconnect."
created_at: 2026-02-08
tags: ["ui", "connection"]
icon: power
build: 56
---


# Connection Toggle Toolbar Button
**Stage**: testing
**Created**: 2026-02-08

## What
Add a connection toggle button to the main toolbar next to the settings gear button (to its left), with a divider in between. Mirrors the left side's Plans|Divider|Memory layout.

## Behavior
- **Connected** (isAuthenticated): Red-tinted power icon — tap to disconnect
- **Disconnected** (!isAuthenticated): Green-tinted power icon — tap to reconnect
- Uses `reconnectIfNeeded()` for connect, `disconnect(clearCredentials: false)` for disconnect
- Colors are muted red/green shades that fit the ocean theme

## Files Changed
- `Cloude/Cloude/App/CloudeApp.swift` — toolbar trailing item gets connection toggle + divider + gear
