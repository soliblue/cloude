# Skill: Screen Time / App Usage

## What
App usage tracking from macOS Knowledge Store (knowledgeC.db). Shows time spent per app.

## Scripts
- `usage-today.sh` — Today's app usage sorted by duration
- `usage-history.sh` — Usage for a specific date (YYYY-MM-DD)
- `usage-summary.sh` — Multi-day summary with top app per day

## Permissions Needed
- Full Disk Access (for knowledgeC.db)

## Testing
- [ ] `usage-today.sh` shows today's app usage
- [ ] `usage-history.sh 2026-02-13` shows specific date
- [ ] `usage-summary.sh 7` shows weekly summary
