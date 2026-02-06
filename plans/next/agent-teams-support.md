# Agent Teams Support

Surface Claude Code's agent teams feature in Cloude so users can spawn, monitor, and interact with multi-agent teams from iOS.

## Background

Opus 4.6 shipped agent teams (experimental) — multiple Claude Code instances coordinating on a task with a shared task list and inter-agent messaging. Currently CLI-only with in-process or tmux display modes.

### How It Works (CLI)
- Enable: `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` env var
- One session is **team lead**, spawns **teammates** (each a separate Claude Code process)
- Shared **task list** at `~/.claude/tasks/{team-name}/`
- Team config at `~/.claude/teams/{team-name}/config.json` (member names, agent IDs, types)
- Teammates communicate via **mailbox** messaging system (message one or broadcast all)
- Task states: pending → in progress → completed, with dependency tracking
- Lead can use **delegate mode** (coordination-only, no code touching)
- In-process mode: Shift+Up/Down to select teammates, type to message directly

### The Vision
Point a team at `plans/next/`, have teammates each claim a ticket and implement in parallel. Monitor everything from your phone. One session = entire sprint.

## Goals
- Spawn agent teams from iOS (tell the lead what to do, it creates the team)
- See all teammates and their current status/task
- View the shared task list with real-time progress
- Message individual teammates directly from iOS
- See teammate output streams (what each agent is doing)

## Phases

### Phase 1: Enable + Basic Monitoring
- Pass `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` when spawning Claude Code in `ClaudeCodeRunner`
- Parse teammate spawn/status events from lead's stdout
- Show teammate list in UI (name, status, current task)
- All interaction goes through the lead — user talks to lead, lead coordinates

### Phase 2: Task List UI
- Read shared task list from `~/.claude/tasks/{team-name}/`
- Display tasks with status (pending/in-progress/completed) and assignee
- Real-time updates as teammates claim and complete tasks
- Dependency visualization (which tasks are blocked)

### Phase 3: Direct Teammate Interaction
- Select a teammate from the list to view their output stream
- Send messages directly to individual teammates (bypass lead)
- Per-teammate conversation view (like switching between conversations)

### Phase 4: Team Management UI
- Spawn/shutdown teammates from iOS
- Toggle delegate mode for the lead
- Token usage per teammate
- Team-level overview dashboard

## Tested: Stream JSON Event Structure (2026-02-05)

Ran a live test with `--output-format stream-json --verbose`. All teammate events flow through the lead's stdout — no need to track separate processes.

### Tools Added When Teams Enabled
- `Teammate` — operations: `spawnTeam`, `cleanup`
- `SendMessage` — types: `message`, `shutdown_request`, `broadcast`

### Event Flow (actual observed sequence)

1. **Team creation**: `Teammate` tool call with `{operation: "spawnTeam", team_name, description}`
   - Result: `{team_name, team_file_path, lead_agent_id}`

2. **Teammate spawn**: `Task` tool call with extra `team_name` and `name` fields
   - Result includes `status: "teammate_spawned"` plus:
     - `teammate_id`, `agent_id` (e.g. `"line-counter@line-counter"`)
     - `agent_type`, `model`, `color` (e.g. `"blue"`)
     - `team_name`, `is_splitpane: false`
     - `plan_mode_required: true/false`

3. **Messaging**: `SendMessage` tool call with `{type, recipient, content}`
   - Result: `{success, message, request_id, target}`

4. **Cleanup**: `Teammate` tool call with `{operation: "cleanup"}`
   - Fails if active members remain (must shutdown first)

### Team Config File
Stored at `~/.claude/teams/{team-name}/config.json`:
```json
{
  "name": "line-counter",
  "description": "Count lines in CLAUDE.md",
  "createdAt": 1770323540910,
  "leadAgentId": "team-lead@line-counter",
  "leadSessionId": "3676724f-...",
  "members": [
    {
      "agentId": "team-lead@line-counter",
      "name": "team-lead",
      "agentType": "team-lead",
      "model": "claude-opus-4-6",
      "joinedAt": 1770323540910
    }
  ]
}
```

### Cost Observation
A trivial 1-teammate test cost **$0.33** (~$0.31 Opus lead + $0.003 Haiku teammate). Teams are expensive — cost UI is essential.

### Model Usage Breakdown (from result event)
The `result` event includes `modelUsage` with per-model token counts and costs — perfect for building a cost dashboard.

## Remaining Questions
- **Team lifecycle**: How to handle iOS disconnect/reconnect while a team is running?
- **Session resumption**: Docs say `/resume` doesn't restore in-process teammates — important limitation for our reconnect flow
- **Teammate output**: Do teammate text/tool events also appear in lead's stdout, or just the spawn/message/shutdown events?

## Files
- `Cloude Agent/Services/ClaudeCodeRunner.swift` — env var, process spawning, output parsing
- `Cloude Agent/Services/WebSocketServer.swift` — relay teammate events to iOS
- `Cloude/Models/Messages.swift` — team/teammate/task message types
- `Cloude/UI/` — new team view components (teammate list, task board, teammate chat)
- `CloudeShared/` — shared team/task models

## Token Cost Considerations
- Each teammate = separate Claude Code instance = separate context window
- Token usage scales linearly with teammate count
- Worth showing per-teammate and total team token usage in UI
- Users need to understand the cost tradeoff before spawning large teams

## Notes
- No nested teams (teammates can't spawn their own teams)
- One team per lead session
- Lead is fixed for team lifetime (can't promote teammates)
- All teammates inherit lead's permission mode (we use `--dangerously-skip-permissions`)
- Split-pane mode irrelevant for iOS — in-process is our path
- Teammates load CLAUDE.md automatically, so project context propagates
