# Interactive Chart Component {chart.bar.xaxis}
<!-- priority: 10 -->
<!-- tags: ui, widget -->

> Refactored activity chart into a reusable InteractiveBarChart component.

## What
Refactored the activity chart in UsageStatsSheet into a reusable `InteractiveBarChart` component.

## Changes
- Created `Cloude/Cloude/UI/Charts/InteractiveBarChart.swift` — generic bar chart that works with any `Identifiable` data
- Features: tap-to-select, time range picker (7d/14d/30d/All), customizable x/y values, colors, formatting
- Made `DailyActivity` conform to `Identifiable`
- Fixed cramped x-axis date labels — now shows day numbers with month prefix only on month boundaries
- Refactored `UsageStatsSheet` to use the new component

## Next
See `plans/next/chart-rendering-in-chat.md` for rendering charts inline in chat messages.
