---
title: "Theme Reorder & New Themes"
description: "Added Bauder, Mahfouz, and Tawfik themes, reordered by color family, and renamed ocean* properties to theme*."
created_at: 2026-03-15
tags: ["theme", "ui"]
icon: swatchpalette.fill
build: 86
---


# Theme Reorder & New Themes
## Changes
- Added Bauder theme (dark steel-blue, named after Christopher Bauder)
- Added Mahfouz theme (bicolor: warm amber bg + cool blue-gray surfaces)
- Added Tawfik theme (bicolor: cool dark bg + warm amber surfaces)
- Reordered all themes by color family: lights (white > warm > green > purple > blue), darks (black > gray > blue > indigo > green > amber > red > mixed)
- Renamed all `ocean*` color properties to `theme*` (48 files)

## Files Changed
- `Theme.swift` - new themes, reordered enum
- `Colors.swift` - renamed properties
- 48 UI files - updated color references
