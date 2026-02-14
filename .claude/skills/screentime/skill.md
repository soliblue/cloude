---
name: screentime
description: App usage and screen time from macOS Knowledge Store. Shows time spent in each app, daily breakdowns, and weekly summaries.
user-invocable: true
icon: hourglass
aliases: [screen-time, app-usage, usage]
---

# Screen Time Skill

Reads app usage data from the macOS Knowledge Store (`knowledgeC.db`). Uses `/app/inFocus` stream to track which app was in the foreground and for how long.

## Requirements

The Terminal (or Cloude Agent) needs **Full Disk Access** in System Settings > Privacy & Security > Full Disk Access. Without it, sqlite3 cannot read the database.

## Scripts

### Today's usage
```bash
bash .claude/skills/screentime/usage-today.sh
```
Shows app usage for today sorted by most used. Output: `AppName|Minutes`

### Usage for a specific date
```bash
bash .claude/skills/screentime/usage-history.sh              # Today
bash .claude/skills/screentime/usage-history.sh 2026-02-13   # Specific date
```
Output: `AppName|Minutes`

### Weekly summary
```bash
bash .claude/skills/screentime/usage-summary.sh       # Last 7 days
bash .claude/skills/screentime/usage-summary.sh 14    # Last 14 days
```
Output: `Date|TotalMinutes|TopApp`

## Use Cases
- "How much time did I spend on my phone today?"
- "What apps did I use most this week?"
- "Screen time for yesterday"
- "How much time in Xcode vs Chrome?"
- Heartbeat: surface daily usage patterns

## Notes
- Data comes from `/app/inFocus` events in knowledgeC.db
- macOS keeps ~4 weeks of data
- Bundle IDs are converted to readable app names where possible
- Timestamps use Mac Absolute Time (epoch 2001-01-01)
