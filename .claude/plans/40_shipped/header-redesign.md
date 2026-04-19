---
title: "Header Redesign"
description: "Moved logo left and toolbar buttons right to fix off-center principal item."
created_at: 2026-03-01
tags: ["ui", "header"]
icon: rectangle.topthird.inset.filled
build: 74
---


# Header Redesign
## Problem
Cloude logo in navigation bar was not centered — 3 buttons on the left and 1 on the right made iOS push the `.principal` item off-center.

## Solution
- Moved Cloude logo to the left
- Moved toolbar buttons (brain, plans, clock, power) to the right
- Removed hardcoded offset hack from empty state character

## Files Changed
- `Cloude/Cloude/App/CloudeApp.swift` — toolbar button rearrangement
- `Cloude/Cloude/UI/ConversationView+EmptyState.swift` — removed offset
