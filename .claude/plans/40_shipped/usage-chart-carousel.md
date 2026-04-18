# Usage Chart Carousel {chart.bar.xaxis}
<!-- priority: 10 -->
<!-- tags: ui, settings -->
<!-- build: 86 -->

> Added swipeable carousel of daily bar charts (Messages, Sessions, Tool Calls) with shared time range picker to the usage sheet.

## Goals
- Swipeable carousel of bar charts: Messages, Sessions, Tool Calls
- Shared time range picker (7d, 14d, 30d, All) applies to all charts
- Page indicator dots so user knows there are more charts

## Approach
- Replace the single `activityChart` in `UsageStatsSheet` with a `TabView(.page)` containing 3 `InteractiveBarChart` instances
- Each chart uses the same `recentActivity` data but different y-values and colors
- Time range picker stays shared (already bound to parent state)
- Add page dots via `.tabViewStyle(.page(indexDisplayMode: .always))`

## Files
- `Cloude/Cloude/UI/UsageStatsSheet.swift` - replace `activityChart` with carousel
