---
title: "Tabs Row Text Truncation Bug"
description: "Fixed text truncation in tabs row when long dates and model badges overflow."
created_at: 2026-02-11
tags: ["ui", "header"]
icon: textformat.size
build: 71
---


# Tabs Row Text Truncation Bug {textformat.size}
## Problem
When the date is long (e.g., "Fri, Feb 7") and Sonnet model badge is shown, there's not enough space in the tabs row for everything. The text gets cut off or overlaps.

## Context
The tabs row shows:
- Chat tab (with model badge like "Sonnet")
- Files tab
- Git tab
- Date (e.g., "Fri, Feb 7")
- Cost badge
- Action buttons

Long dates + "Sonnet" badge can overflow on smaller screens.

## Solution Ideas
- Truncate date with ellipsis when space is tight
- Use shorter date format (e.g., "Feb 7" without day name)
- Reduce padding between tabs
- Make model badge shorter (just "S"/"O"/"H"?)
- Dynamic spacing based on available width
- Stack date on second line if needed

## Files
- `Cloude/Cloude/UI/MainChatView.swift` - Tabs row layout (windowHeader function)

## Tag
bug
