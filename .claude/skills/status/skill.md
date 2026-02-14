---
name: status
description: Quick overview of project state - staging, git, open plans. Use when asked "what's the status", "where are we", or at start of session.
user-invocable: true
icon: chart.bar.xaxis
aliases: [overview, where]
---

# Status Skill

Get a quick overview of where things stand.

## Check These

1. **Testing Queue** (plans/30_testing/)
   ```bash
   ls plans/30_testing/ 2>/dev/null | grep -c .md
   ```
   - Count items in `plans/30_testing/`
   - **WARN if 5+ items** — stop adding features, ask the user to test first
   - List the items briefly

2. **Last Deploy** (CLAUDE.local.md)
   - When was last deploy? Extract from "Last Deploy" section
   - Show what changed since last deploy:
   ```bash
   git log --oneline --since="LAST_DEPLOY_DATE"
   ```

3. **Git Status**
   ```bash
   git status --short
   git log --oneline -5
   ```

4. **Open Plans**
   ```bash
   ls plans/20_active/ plans/10_next/ 2>/dev/null
   ```
   Read any active plans to understand ongoing work.

5. **Moltbook** (if relevant)
   - Last check timestamp in CLAUDE.local.md
   - Any engagement on recent posts?

## Output Format

Summarize concisely:
- Testing: X items awaiting test [list names]
- Last deploy: [date] (Build XX), Y commits since
- Git: [clean/dirty], last commit [message]
- Plans: [list active plans or "none"]
- Blockers: [any issues or "none"]

**If 5+ items awaiting test:**
```
TESTING QUEUE FULL - X items awaiting test
Stop adding features until the user tests. Ask: "Ready to test the staging items?"
```
