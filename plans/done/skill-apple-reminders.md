# Apple Reminders Skill {checklist}
<!-- priority: 7 -->
<!-- tags: skill, integration, apple -->

> Create, complete, list, and search reminders via AppleScript. Syncs across all Apple devices via iCloud. Inspired by OpenClaw's apple-reminders skill.

## Approach
Shell scripts wrapping `osascript` — same as calendar skill. No dependencies.

## Commands
- List reminder lists
- View reminders (by list, due date, completed/incomplete)
- Create reminder (title, list, due date, priority, notes)
- Complete / uncomplete reminder
- Delete reminder
- Search reminders by keyword

## Use Cases
- "Remind me to call Mom tomorrow at 5pm"
- "What's on my todo list?"
- "Mark the grocery reminder as done"
- Heartbeat: check overdue reminders, nudge

**Files:** `.claude/skills/reminders/`, shell scripts with AppleScript
