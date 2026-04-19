---
title: "Multi-Theme Support"
description: "Added 9 distinct color themes with per-theme palettes for backgrounds, surfaces, and fills."
created_at: 2026-03-01
tags: ["theme", "ui", "settings"]
icon: paintpalette.fill
build: 82
---


# Multi-Theme Support
## Summary
Add 9 distinct color themes (up from 2 effective themes). Each theme has its own color palette for backgrounds, surfaces, and fills.

## Themes
Ocean Dark, Ocean Light, Midnight, Solarized Dark, Solarized Light, Monokai, Nord, Dracula, GitHub Light

## Files
- `Theme.swift` - ThemePalette struct + 9 palettes
- `Colors.swift` - Dynamic ocean colors from current palette
- `SettingsView+Theme.swift` - Theme picker grid (NEW)
- `SettingsView.swift` - Link to theme picker
- `CloudeApp.swift` - Update default
