---
title: "Android Usage Stats"
description: "View usage statistics: sessions, tokens, costs, daily activity charts."
created_at: 2026-03-29
tags: ["android", "stats"]
build: 120
icon: chart.bar
---
# Android Usage Stats


## Desired Outcome
Usage stats sheet showing total tool calls, days active, member since date, activity chart, model usage breakdown, and peak hour identification.

## iOS Reference Architecture

### Data flow
1. Client sends `getUsageStats` message on sheet open
2. Server responds with `ServerMessage.UsageStats` containing daily activity data, tool call counts, model breakdown

### UI structure
- `UsageStatsSheet.swift` - modal sheet with stats summary and charts
- `UsageStatsSheet+LineChart.swift` - custom Canvas-based activity chart with time range selector (7d, 14d, 30d, all)
- `UsageStatsSheet+Helpers.swift` - data transformation for chart rendering
- Stats displayed: total tool calls, days active, member since, peak hour, model output token breakdown (opus/sonnet/haiku percentages)

### Android implementation notes
- Use Compose Canvas for line chart or `androidx.compose.foundation.Canvas`
- Time range tabs with `TabRow`
- `ModalBottomSheet` with scrollable content
- `ServerMessage.UsageStats` already in message enum (needs parsing + UI)
- Stats summary as a grid of cards above the chart

**Files (iOS reference):** UsageStatsSheet.swift (+LineChart, +Helpers)
