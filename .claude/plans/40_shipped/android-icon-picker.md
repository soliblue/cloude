---
title: "Android Window Icon Picker"
description: "Searchable icon picker for assigning custom icons to windows."
created_at: 2026-04-05
tags: ["android", "windows", "ux"]
build: 125
icon: square.grid.2x2
---
# Android Window Icon Picker


## Desired Outcome
Each window can have a custom Material Icon selected from a searchable grid picker. Icon persists per window in WindowManager.

## Scope
- Add icon field to ChatWindow model
- Icon picker sheet with category tabs and search
- Persist icon choice in WindowManager (SharedPreferences)
- Display chosen icon in window tab bar and conversation info label

## iOS Reference
- 18 categories, grid layout, searchable

## Implementation
- IconPickerSheet.kt with LazyVerticalGrid of Material Icons
- Search filters icons by name
- Categories: General, Communication, Navigation, Files, Media, etc.
- Wire into window edit flow
