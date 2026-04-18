---
title: "Clean Up Themes"
description: "Remove 17 unused themes and 3 redundant palette slots."
created_at: 2026-03-24
tags: ["ui", "cleanup"]
icon: paintpalette
build: 103
---


# Clean Up Themes {paintpalette}
## Changes

### 1. Remove 17 themes
Keep: Monet (white light), Turner (warm light), Bauder (slate dark), Majorelle (indigo dark, default), Klimt (amber dark), Malevich (pure black)

### 2. Remove 3 redundant palette slots
- Drop groupedSecondary (0 usages)
- Replace themeGray6 with themeSecondary (always same value)
- Replace themeSystemBackground with themeBackground (always same value)

ThemePalette: 8 fields to 5 (background, secondary, surface, tertiary, fill)

### 3. Migration
Users with removed theme in UserDefaults fall through to .majorelle default.

## Files
- Theme.swift, Theme+Palettes.swift, Colors.swift, SettingsView+Theme.swift
- ~20 UI files referencing themeGray6 and themeSystemBackground
