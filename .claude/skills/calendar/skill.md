---
name: calendar
description: Read, create, update, and delete Apple Calendar events. Real-time access via AppleScript — always current, no export needed.
user-invocable: true
icon: calendar
aliases: [cal, schedule, events]
---

# Apple Calendar Skill

Real-time access to Calendar.app via AppleScript. All commands hit the live calendar — no caching, no export step.

## First-Time Setup

Run any script once from Terminal to trigger the macOS permission dialog:
```bash
bash .claude/skills/calendar/cal-list.sh
```
Click "Allow" in System Settings → Privacy & Security → Automation → Terminal → Calendar.

## Scripts

### List calendars
```bash
bash .claude/skills/calendar/cal-list.sh
```

### View upcoming events
```bash
bash .claude/skills/calendar/cal-events.sh              # Next 7 days, all calendars
bash .claude/skills/calendar/cal-events.sh 1             # Today only
bash .claude/skills/calendar/cal-events.sh 14            # Next 14 days
bash .claude/skills/calendar/cal-events.sh 7 "Personal"  # Next 7 days, one calendar
```

### Search events
```bash
bash .claude/skills/calendar/cal-search.sh "dentist"              # Search next 30 days
bash .claude/skills/calendar/cal-search.sh "meeting" 90            # Search next 90 days
bash .claude/skills/calendar/cal-search.sh "standup" 7 "Work"      # Search specific calendar
```

### Create event
```bash
bash .claude/skills/calendar/cal-create.sh "Personal" "Dinner with Adam" "2026-02-15 19:00" "2026-02-15 21:00"
bash .claude/skills/calendar/cal-create.sh "Personal" "Dentist" "2026-02-15 10:00" "2026-02-15 11:00" "123 Main St"
bash .claude/skills/calendar/cal-create.sh "Personal" "Mom Birthday" "2026-03-01" "" "" "" "allday"
```
Args: calendar, title, start, end, [location], [notes], [allday]

### Delete event
```bash
bash .claude/skills/calendar/cal-delete.sh "EVENT_UID" "Personal"
```
Use the UID from cal-events.sh or cal-search.sh output.

## Output Format

Events are returned as pipe-separated values:
```
UID|Summary|Start|End|AllDay|Location|Calendar
```

## Security
- Read-only operations run without confirmation
- Create/delete operations: always confirm with user before executing
- No data leaves the Mac — pure local AppleScript
