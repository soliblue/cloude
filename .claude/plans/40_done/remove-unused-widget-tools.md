# Remove Unused Widget Tools
<!-- build: 121 -->
<!-- priority: 3 -->
<!-- tags: tools, ui -->

> Removed unused widget MCP tools and their dead app-side widget views to reduce tool/context surface area.

## Problem
The widget MCP server still exposed tools that are not part of the current workflow: `interactive_function`, `bar_chart`, `scatter_plot`, `function_plot`, and `line_chart`. Their corresponding widget views also remained in the app, which made the surface area larger than needed and kept stale docs around old capabilities.

## Fix
Pruned the widget MCP server down to the widgets we still want:
- `pie_chart`
- `timeline`
- `image_carousel`
- `color_palette`
- `tree`

Removed the matching app-side widget registry entries and deleted the dead widget view files for:
- `InteractiveFunctionWidget`
- `BarChartWidget`
- `ScatterPlotWidget`
- `FunctionPlotWidget`
- `LineChartWidget`
- `ExpressionParser`

Updated live docs to reflect the current widget set.

**Files:** `.claude/widgets-mcp/server.js`, `Cloude/Cloude/UI/WidgetView+Registry.swift`, `CLAUDE.md`, `README.md`, `interactive-widgets-architecture.md`

## Test
- [ ] Fresh session no longer shows `mcp__widgets__interactive_function`
- [ ] Fresh session no longer shows `mcp__widgets__bar_chart`
- [ ] Fresh session no longer shows `mcp__widgets__scatter_plot`
- [ ] Fresh session no longer shows `mcp__widgets__function_plot`
- [ ] Fresh session no longer shows `mcp__widgets__line_chart`
- [ ] Remaining widgets still render correctly: pie chart, timeline, image carousel, color palette, tree
- [ ] Docs only describe the current widget set
