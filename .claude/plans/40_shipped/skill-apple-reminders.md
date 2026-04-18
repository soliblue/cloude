---
title: "Apple Reminders Skill"
description: "Built Apple Reminders skill with CRUD operations and search via AppleScript."
created_at: 2026-02-14
tags: ["skill", "integration", "apple"]
icon: checklist
build: 71
---


# Apple Reminders Skill {checklist}
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
