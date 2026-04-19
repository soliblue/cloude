# Bring widgets back

Widgets + iOS actions were ripped out (see commit after widget-removal sweep) because they were over-engineered for the current feature set and polluted `ConnectionEvent`, `EnvironmentConnection+IOSTools`, `ToolMetadata`, `InlineToolPill`, `MessageBubble`, and had their own per-widget rendering files.

Bring them back once the `ConnectionManager` / `EnvironmentConnection` refactor is settled and the architecture is clean enough that adding a new rendered tool is a 1-file change, not a 6-file change.

## What was removed

**Widgets** (custom rendered views in message bubbles):
- `pie_chart` — proportions (code composition, test coverage, disk usage)
- `timeline` — vertical event timeline with SF Symbol icons
- `image_carousel` — swipeable image viewer
- `color_palette` — labeled color swatches
- `sf_symbols` — grid of SF Symbols
- `tree` — collapsible hierarchical tree

**Actions** (side-effect tools):
- `rename` — Claude renames the current conversation mid-stream
- `symbol` — Claude sets the conversation's SF Symbol icon
- `clipboard` — copy text to iOS clipboard
- `screenshot` — capture iOS screen

Automatic early naming (`requestNameSuggestion` → `handleNameSuggestion`) was KEPT — that's a message-based path, not an MCP tool.

## What the clean architecture should look like

Before adding widgets back, the refactor needs:

- A single typed iOS-tool registry at the boundary (kills the current stringly-typed `hasPrefix("mcp__ios__*")` dispatch).
- A clean handoff from tool call → rendered view (`ToolCall → ConnectionEvent → View`), preferably one place where new tools slot in without touching `MessageBubble` / `InlineToolPill` / `ToolMetadata` separately.
- MCP server tool definitions co-located with their iOS renderers so the schema lives next to the view.

## Concrete starter list for v2

1. `tree` — most universally useful (file listings, dependency graphs).
2. `image_carousel` — screenshots + before/after comparisons.
3. `clipboard` — small, no rendering, good test of the action pathway.

Skip `rename` / `symbol` as MCP tools — automatic naming already covers the common case, and mid-stream renames are noisy UX.

## Files to reference when rebuilding

- `.claude/ios-mcp/server.js` — still present, currently loads an empty tool set.
- `.claude/ios-mcp/tools/` — where tool schemas should go.
- Old implementation lives in git history (look for commits with "widgets" or "actions" in the message around the time of this plan).
