---
title: "Fix Theme Persistence Across App Restarts"
description: "Fixed theme resetting to default on app restart by storing raw string in AppStorage instead of enum."
created_at: 2026-03-01
tags: ["theme", "settings"]
icon: paintbrush.fill
build: 82
---


# Fix Theme Persistence Across App Restarts {paintbrush.fill}
## Problem
Selected theme resets to Ocean Dark after restarting the app.

## Root Cause
`@AppStorage` with `RawRepresentable` enum types (`AppTheme`) has inconsistent persistence behavior in SwiftUI — the stored format may not round-trip correctly across app launches.

## Fix
Changed all `@AppStorage("appTheme")` declarations from storing `AppTheme` directly to storing a raw `String`, with a computed property to convert back to the enum.

## Files Changed
- `CloudeApp.swift` — main app theme binding
- `SettingsView.swift` — settings theme reference
- `SettingsView+Theme.swift` — theme picker (where selection happens)
