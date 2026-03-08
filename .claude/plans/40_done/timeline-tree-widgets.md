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
