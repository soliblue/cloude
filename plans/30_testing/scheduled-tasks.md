# Scheduled Tasks

## Summary
Give Cloude the ability to schedule tasks that run autonomously at specific times or intervals. Each scheduled task is its own conversation with its own memory/context.

## Motivation
Currently Cloude can only act when prompted (user message or heartbeat). Scheduled tasks let Cloude work autonomously — morning briefings, periodic checks, recurring automations, delayed actions — without Soli needing to be present.

## Design

### How It Works
1. **Soli asks Cloude** to schedule something in conversation ("check Manifold markets every morning", "remind me to deploy at 3am")
2. **Cloude creates the task** via `cloude schedule` command — specifying prompt, time/interval, and any context
3. **Mac agent runs a scheduler** that spawns Claude Code sessions at the right times
4. **Each task = a conversation** — has its own session ID, memory, message history. Repeated tasks resume the same conversation each time, building context over runs
5. **iOS shows all scheduled tasks** — view upcoming, see past results, deactivate, delete

### Task Types
- **One-time**: runs once at a specific time, then done
- **Recurring**: runs on a schedule (daily, weekly, cron-style), conversation persists across runs

### iOS UI
- **No changes to windows or conversations** — scheduled tasks are just normal conversations
- New **clock button** top-left in header (next to plans button) opens a **Scheduled Tasks sheet**
- Sheet lists all tasks with: name, schedule info, next run time, active/inactive toggle, delete
- Tapping a task refreshes its messages then opens it as a normal window
- Task creation/editing happens through Cloude in conversation (not through iOS UI) — iOS is view/toggle/delete only

### Mac Agent
- `SchedulerService` — stores tasks as JSON, runs a timer, spawns Claude Code sessions on schedule
- Each task stored with: id, name, prompt, schedule (cron or ISO date), conversationId, active flag, createdAt
- On trigger: spawns Claude Code with `--resume` using the task's conversation ID
- Task results flow back through normal WebSocket → iOS sees them as conversation messages

### CLI Command
```bash
cloude schedule --name "Market Check" --prompt "Check my Manifold positions" --cron "0 9 * * *"
cloude schedule --name "Deploy Reminder" --prompt "Remind Soli to deploy" --at "2026-02-18T03:00:00"
cloude schedule --list
cloude schedule --delete <id>
cloude schedule --toggle <id>
```

### Shared Model (CloudeShared)
```
ScheduledTask {
    id: UUID
    name: String
    prompt: String
    schedule: OneTime(Date) | Recurring(CronExpression)
    conversationId: String
    isActive: Bool
    lastRun: Date?
    createdAt: Date
}
```

## Scope
- **Mac agent**: SchedulerService, task JSON storage, session spawning on schedule
- **iOS app**: scheduled tasks list view, activate/deactivate/delete, link to conversation
- **CLI**: `cloude schedule` command for creating/listing/managing tasks
- **CloudeShared**: ScheduledTask model + messages for sync

## Status
Planning — ready for architecture review.
