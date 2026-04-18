---
title: "Sheet Theme Sync Fix"
description: "Fixed sheets not updating colors when switching themes by adding preferredColorScheme to each sheet."
created_at: 2026-03-01
tags: ["theme", "ui"]
icon: paintbrush
build: 82
---


# Sheet Theme Sync Fix {paintbrush}
## Summary
Sheets (Settings, Theme Picker) didn't update colors when switching themes because `.preferredColorScheme` was only on the root CloudeApp view. Sheets are separate presentation contexts.

## Fix
Added `.preferredColorScheme(appTheme.colorScheme)` to both `SettingsView` and `ThemePickerView`.

## Files
- `SettingsView.swift` - Added `.preferredColorScheme`
- `SettingsView+Theme.swift` - Added `.preferredColorScheme`
