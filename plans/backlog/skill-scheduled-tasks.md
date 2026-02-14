# Scheduled Tasks / Cron Skill {clock.badge.checkmark}
<!-- priority: 7 -->
<!-- tags: skill, automation -->

> Schedule recurring or one-off tasks that Cloude executes autonomously. Goes beyond heartbeat — specific actions at specific times.

## Approach
JSON file of scheduled tasks, checked by the Mac agent on a timer (or by heartbeat). Each task has a schedule (cron syntax or relative time), an action (skill invocation, message, bash command), and status.

## Commands
- Schedule a task ("every morning at 8am, summarize my calendar")
- List scheduled tasks
- Cancel / pause a task
- View task history (last runs, results)

## Examples
- "Every morning at 8am: check calendar, check email, give me a briefing"
- "In 2 hours, remind me to call the dentist"
- "Every Friday at 5pm: summarize this week's git activity"
- "Every day at midnight: check Manifold markets"

## Architecture
- Task definitions stored in `~/.cloude/scheduled-tasks.json`
- Mac agent checks schedule on timer or heartbeat trigger
- Each task spawns a short Claude session to execute
- Results logged and optionally pushed to iOS via `cloude notify`

**Files:** `.claude/skills/schedule/`, Mac agent timer service
