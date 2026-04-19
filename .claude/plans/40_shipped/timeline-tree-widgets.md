---
title: "Timeline & Tree Display Widgets"
description: "Added timeline and tree MCP widget tools with SwiftUI views for event sequences and hierarchical data."
created_at: 2026-03-04
tags: ["widget"]
icon: list.bullet.indent
build: 82
---


# Timeline & Tree Display Widgets
## Problem
No display-only informational widgets — only charts and exercises. Missing timeline (events) and tree (hierarchy) visualizations.

## Solution
Add two new MCP widget tools + SwiftUI views:
- `timeline` — vertical event timeline with dates, titles, SF Symbol icons, colors
- `tree` — hierarchical tree diagram with collapsible nodes, SF Symbol icons

## Files
- `Cloude/Cloude/UI/Widgets/WidgetView+Timeline.swift` — new
- `Cloude/Cloude/UI/Widgets/WidgetView+Tree.swift` — new
- `Cloude/Cloude/UI/Widgets/WidgetView+Registry.swift` — register both
