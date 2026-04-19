---
title: "Theme Reactivity Fix"
description: "Fixed theme picker cards and existing messages not updating colors when switching themes by adding reactive environment key."
created_at: 2026-03-13
tags: ["theme", "ui"]
icon: paintbrush.pointed.fill
build: 86
---


# Theme Reactivity Fix
## Problem
When switching themes, some UI elements kept the old theme colors:
1. Theme picker cards had stale backgrounds
2. Existing user messages in chat didn't update colors

## Root Cause
`Color.ocean*` static properties read from `UserDefaults` via `AppTheme.current`, which SwiftUI doesn't track as reactive state. Views with no other changing props (like already-sent user messages) never re-rendered.

## Fix
- **Theme picker**: Replaced `Color.oceanSecondary`/`Color.oceanBackground` with `Color(hex: appTheme.palette.xxx)` derived from `@AppStorage`
- **Message bubbles**: Added `@Environment(\.appTheme)` environment key (new `AppThemeKey` in Theme.swift), injected from `CloudeApp`, read in `MessageBubble` for background color computation

## Files Changed
- `Utilities/Theme.swift` - Added `AppThemeKey` environment key
- `App/CloudeApp.swift` - Injects `.environment(\.appTheme, appTheme)`
- `UI/MessageBubble.swift` - Reads `@Environment(\.appTheme)` for reactive background colors
- `UI/SettingsView+Theme.swift` - Theme picker uses reactive colors + passes `currentTheme` to cards

## Test
- Switch between dark and light themes in the picker
- Verify all theme cards update backgrounds instantly
- Verify existing user messages in chat update colors on theme change
