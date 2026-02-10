# Native Chat Components (Charts, Cards, UI Elements)

## Summary
Allow Claude to render rich native UI elements inline in chat — charts, cards, progress bars, interactive components — instead of just text/markdown. The chat adapts visually based on responses.

## Motivation
Currently chat output is limited to markdown text, code blocks, and tool pills. Many responses would benefit from native rendering: usage stats as charts, data as tables with sorting, progress as visual bars, comparisons as side-by-side cards. Instead of describing data, show it.

## Possible Components
- **Charts**: Bar, line, pie (SwiftUI Charts) — for stats, trends, comparisons
- **Cards**: Highlighted info blocks with icons — for summaries, key metrics
- **Progress bars**: Visual completion indicators — for build status, quotas
- **Interactive tables**: Sortable/filterable data grids — for file lists, search results
- **Image grids**: Thumbnail layouts — for generated images, screenshots
- **Polls/votes**: Tappable options — for decision making

## Open Questions
- How does Claude signal "render this as a chart"? Special markdown syntax? JSON blocks? Tool calls?
- Should components be static or interactive (tappable, expandable)?
- How to handle fallback when a component type isn't supported?
- Does the agent need to be involved or can iOS parse/render autonomously?

## Prior Art
- Artifacts in Claude.ai (renders React components)
- Slack Block Kit (structured message layouts)
- Notion inline databases

## Status
- **Stage**: next
- **Priority**: low
- **Complexity**: high — needs protocol design, renderer, Claude awareness
