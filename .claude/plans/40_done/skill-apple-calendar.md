# Apple Calendar Skill {calendar}
<!-- priority: 8 -->
<!-- tags: skill, integration, apple -->

> Built Apple Calendar skill with CRUD operations, search, and recurring events via AppleScript.

## Approach
Shell scripts wrapping `osascript` AppleScript commands — same pattern as OpenClaw. No API keys, no dependencies. Runs on the Mac agent.

## Commands
- List calendars
- View upcoming events (next N days, optional calendar filter)
- Create event (calendar, title, start, end, location, notes, all-day, recurrence)
- Update event by UID
- Delete event by UID
- Search events by keyword

## Use Cases
- "What's on my calendar today?"
- "Schedule a meeting with X tomorrow at 3pm"
- "Move my dentist appointment to Thursday"
- Heartbeat: proactive morning briefing with today's schedule

**Files:** `.claude/skills/calendar/`, shell scripts with AppleScript
