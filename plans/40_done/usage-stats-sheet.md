# Usage Stats Sheet (`/usage`)
<!-- build: 70 -->

## Summary
Native iOS sheet showing Claude Code usage statistics from `~/.claude/stats-cache.json`. Triggered by `/usage` slash command — intercepts before reaching CLI and opens a native SwiftUI sheet.

## Data Source
- Mac agent reads `~/.claude/stats-cache.json` and sends it to iOS
- Stats cache is maintained by Claude Code CLI automatically
- Contains: daily activity, model tokens, totals, peak hours, longest session
- No rate limit / remaining quota info available (lives on Anthropic's servers)

## UI Design

### Hero Stats (top row, 3-4 cards)
- Total messages (89K+)
- Total sessions (1,356)
- Days active (count of dailyActivity entries)
- Total tool calls (sum from dailyActivity)

### Daily Activity Chart
- Bar chart showing last 14 days of message counts
- X-axis: dates, Y-axis: message count
- Tappable bars could show session/tool breakdown

### Model Usage Breakdown
- Horizontal bars or segments per model
- Show output tokens (most meaningful metric)
- Color-coded: Opus 4.5 = purple, Opus 4.6 = blue, Sonnet = orange, Haiku = green

### Peak Hours
- 24 mini vertical bars (one per hour)
- Shows session distribution across the day
- Highlight current hour

### Footer
- "Member since Dec 29, 2025"
- Longest session: 607 messages

## Interaction
- `/usage` slash command opens the sheet (intercepted on iOS side, never sent to CLI)
- Also accessible from Settings as a "Usage Stats" row
- Same sheet in both cases

## Implementation

### Agent Side
- New command type: `usage` request/response
- Agent reads `~/.claude/stats-cache.json` from disk
- Sends full JSON to iOS app

### iOS Side
- `UsageStatsSheet.swift` — main sheet view with SwiftUI Charts
- Add `/usage` to `builtInCommands` in `SlashCommand.swift`
- Intercept `/usage` in input handling — send request to agent instead of CLI
- Parse stats JSON and render natively
- Add "Usage Stats" row in Settings that opens the same sheet

### Message Flow
1. User types `/usage` → iOS sends `{ type: "usage" }` to agent
2. Agent reads stats-cache.json → sends `{ type: "usage_stats", data: {...} }` back
3. iOS parses and shows `UsageStatsSheet`

## Status
- **Stage**: active
- **Priority**: medium
- **Complexity**: medium
