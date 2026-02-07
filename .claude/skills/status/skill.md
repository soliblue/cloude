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

1. **Staging** (CLAUDE.local.md)
   - How many items awaiting test?
   - When was last deploy?
   - **WARN if 5+ untested items** - stop adding features, ask Soli to test first

2. **Git Status**
   ```bash
   git status --short
   git log --oneline -3
   ```

3. **Open Plans**
   ```bash
   ls -la plans/
   ```
   Read any active plans to understand ongoing work.

4. **Moltbook** (if relevant)
   - Last check timestamp in CLAUDE.local.md
   - Any engagement on recent posts?

## Output Format

Summarize concisely:
- Staging: X awaiting test, last deploy [date] (Build XX)
- Git: [clean/dirty], last commit [message]
- Plans: [list active plans or "none"]
- Blockers: [any issues or "none"]

**If 5+ items awaiting test:**
```
⚠️ STAGING FULL - 7 items awaiting test
Stop adding features until Soli tests. Ask: "Ready to test the staging items?"
```
