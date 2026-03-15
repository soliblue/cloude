# Usage Chart Carousel
<!-- build: 86 -->

Add multiple daily charts in a swipeable carousel to the usage sheet. Currently there's one "Activity" bar chart showing messages/day. Add sessions/day and tool calls/day as additional pages.

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
