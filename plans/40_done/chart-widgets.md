# Chart Widgets

Added 4 chart widget types for education/math use cases.

## Widgets Added
- **Bar Chart** — category comparisons, histograms, frequency distributions
- **Pie Chart** — proportions, percentages, part-of-whole (donut style with legend)
- **Scatter Plot** — data point relationships, correlations
- **Line Chart** — time series, trends, multi-series support

## Changes
- `widgets-mcp/server.js` — 4 new tool definitions with JSON schemas
- `WidgetView+BarChart.swift` — Swift Charts BarMark with gradient fill, configurable color
- `WidgetView+PieChart.swift` — SectorMark donut with FlowLayout legend
- `WidgetView+ScatterPlot.swift` — PointMark with optional axis labels
- `WidgetView+LineChart.swift` — LineMark with multi-series + legend
- `WidgetView+Registry.swift` — registered all 4 chart types

## Tested
All 4 tools confirmed working after MCP server restart.
