---
title: "Compact Tree Widget"
description: "Made tree widget more compact by removing header, shrinking fonts/icons, and tightening indentation."
created_at: 2026-03-15
tags: ["widget", "ui"]
icon: list.bullet.indent
build: 86
---


# Compact Tree Widget
Removed header, smaller font/icons, added icon-label spacing, tighter indentation. More compact overall.

## Changes
- Removed `WidgetHeader` (title bar + expand/collapse buttons)
- Font: 13pt → 12pt labels, 12pt → 10pt icons, 8pt → 7pt chevrons
- Icon frame: 18pt → 14pt
- Added 5pt spacer between icon and label
- Indent guides: 20pt → 16pt, padding 9 → 7
- Branch connectors: 12pt → 10pt width, frame 16 → 13

## Test
- Send a tree widget and verify it renders compact
- Folders still collapsible
- Tree lines align properly at multiple nesting levels
