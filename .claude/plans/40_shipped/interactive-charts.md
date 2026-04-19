---
title: "Interactive Chart Widgets"
description: "Added tap/drag interactivity to all four chart widgets for data point inspection."
created_at: 2026-03-04
tags: ["widget", "ui"]
icon: hand.tap
build: 82
---


# Interactive Chart Widgets
## Summary
Add tap/drag interactivity to all four chart widgets so users can inspect data points.

## Changes
- **Bar Chart**: Tap bar → highlight + value tooltip annotation
- **Pie Chart**: Tap slice → expand + show label/value/percentage
- **Scatter Plot**: Tap near point → highlight + show coordinates/label
- **Line Chart**: Drag across → vertical rule line showing values at x position

## Implementation
- Use `@State var selectedIndex` + `.chartOverlay` with gesture handling
- `chart.value(atX:)` to map touch position to data
- `RuleMark` / `.annotation` for tooltips
- Haptic feedback on selection
