# Agent Teams Support

Surface Claude Code's agent teams in Cloude — spawn teams, watch teammates work as floating orbs, read their messages, track costs. All from your phone.

## The Vision

Point a team at `plans/next/`, have teammates each claim a ticket and implement in parallel. Monitor everything from your phone. One session = entire sprint.

## CLI Behavior (Tested 2026-02-07)

### How Teams Work
- Enable: `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` env var
- One session is **team lead**, spawns **teammates** (each a separate Claude Code process)
- All teammate events flow through the lead's stdout — no separate process tracking
- Communication happens via **mailbox files** on disk (`~/.claude/teams/{name}/inboxes/`)

### Tools Added When Teams Enabled
The `init` system event `tools` array includes:
- **`TeamCreate`** — creates team, returns `team_name`, `team_file_path`, `lead_agent_id`
- **`TeamDelete`** — cleans up team (fails if teammates still active)
- **`SendMessage`** — types: `message`, `shutdown_request`, `broadcast`, `shutdown_response`

### Event Sequence (from lead's stdout stream-json)

```
1. init          → tools array includes TeamCreate/TeamDelete/SendMessage
2. TeamCreate    → tool_use_result: {team_name, team_file_path, lead_agent_id}
3. Task          → input has team_name + name fields
                 → tool_use_result: {status: "teammate_spawned", teammate_id, name, color, model, agent_type}
4. (lead idles)  → stop_reason: null, then system re-init
5. SendMessage   → tool_use_result: {success, message, request_id, target}
6. TaskOutput    → tool_use_result: {task_type: "in_process_teammate", status: "completed", output: ""}
7. TeamDelete    → tool_use_result: {success: true/false}
8. result        → modelUsage with per-model cost breakdown
```

**Critical finding**: Teammate-to-lead messages appear as `<teammate-message>` XML tags embedded in the lead's assistant text output (not as structured events).

### Filesystem: The Real-Time Source of Truth

**Config** (`~/.claude/teams/{name}/config.json`):
```json
{
  "name": "test-team",
  "description": "Parallel task execution",
  "createdAt": 1770458200246,
  "leadAgentId": "team-lead@test-team",
  "leadSessionId": "1ff8c849-...",
  "members": [
    {"agentId": "team-lead@test-team", "name": "team-lead", "agentType": "team-lead", "model": "claude-opus-4-6", "joinedAt": ..., "cwd": "/path"},
    {"agentId": "scanner@test-team", "name": "scanner", "agentType": "Bash", "model": "claude-opus-4-6", "color": "blue", "prompt": "...", "backendType": "in-process", "joinedAt": ...}
  ]
}
```
- Members list updates live (teammates added on spawn, removed after shutdown)
- Config persists until `TeamDelete` or manual cleanup

**Inboxes** (`~/.claude/teams/{name}/inboxes/{agent}.json`):
```json
// team-lead inbox — receives teammate messages
[
  {"from": "scanner", "text": "UI directory contains 59 Swift files.", "summary": "UI directory contains 59 Swift files", "timestamp": "2026-02-07T09:56:48.033Z", "color": "blue", "read": true},
  {"from": "git-info", "text": "Here's the recent git history:\n\n```\nd7de737 chore: Move...\n```", "summary": "Recent git history retrieved", "timestamp": "2026-02-07T09:56:49.285Z", "color": "green", "read": true},
  {"from": "scanner", "text": "{\"type\":\"idle_notification\",...}", "timestamp": "...", "color": "blue", "read": true},
  {"from": "scanner", "text": "{\"type\":\"shutdown_approved\",...}", "timestamp": "...", "color": "blue", "read": true}
]
```

**Message types in inboxes:**
- **Work messages**: `text` + `summary` + `color` (teammate reports results)
- **`idle_notification`**: teammate finished and is available (JSON in `text` field)
- **`shutdown_approved`**: teammate accepted shutdown request
- **`shutdown_request`**: lead requesting teammate to shut down

### What We CAN Show Live
| Data | Source | Latency |
|------|--------|---------|
| Team creation | Lead's stdout | Instant |
| Teammate spawn (name, color, model) | Lead's stdout | Instant |
| Teammate messages + summaries | Inbox file polling | ~1-2s |
| Teammate idle/active status | Inbox `idle_notification` | ~1-2s |
| Teammate shutdown status | Inbox `shutdown_approved` | ~1-2s |
| Inter-agent message flow | Both inbox files | ~1-2s |
| Member list changes | Config file polling | ~1-2s |
| Per-model cost breakdown | `result` event | End of session |

### What We CANNOT Show
- Teammate tool calls or intermediate work steps (their stdout is invisible to us)
- Real-time progress between messages (only see final results when teammate sends a message)

## UI Design: Floating Orbs

### Core Concept
Each teammate is a **colored floating orb** — alive, pulsing, visible at a glance. Not buried in a sheet or list. The team exists as a living layer over the conversation.

### Orb Behavior
- **Spawning**: Orb appears with scale-up animation, colored per teammate's `color` field
- **Working**: Gentle pulse animation (breathing effect)
- **Idle**: Static, slightly dimmed
- **Sending message**: Brief glow burst, connecting line to lead
- **Shutdown**: Shrink + fade out

### Orb Placement
- Float along the **right edge** of the chat view, vertically stacked
- Each orb shows the teammate's first initial
- Small model badge below (O for Opus, S for Sonnet, H for Haiku)
- Orbs don't overlap with message bubbles (offset from edge)

### Tap → Teammate Card (Popover)
Tapping an orb opens a compact card:
- Name + full color indicator
- Model + agent type
- Current status (working / idle / shutting down)
- Last message summary
- Time since spawn
- Cost (if available)
- Quick action: "Message" or "Shutdown"

### Team Header Banner
When a team is active, a slim banner appears below the conversation header:
- Team name + teammate count
- Row of colored dots (mini orbs)
- Total cost so far
- Tap to open full team sheet

### Team Sheet (Full Dashboard)
Swipe up from banner or tap "View Team":
- **All teammates** as cards with full status
- **Message timeline**: Chronological feed of all inter-agent messages
- **Cost breakdown**: Per-model bar chart
- **Quick actions**: Broadcast message, shutdown all

### Special Tool Pill Rendering
In the chat stream, team-related tool calls get special treatment:
- `TeamCreate` pill: team icon + team name
- `Task` (teammate spawn): colored badge with teammate name
- `SendMessage`: shows sender → recipient with message preview
- `TeamDelete`: cleanup icon

## Implementation Plan

### Phase 1: Enable + Parse + Floating Orbs
**Goal**: See teammates as floating orbs, detect team capability, render team tool pills

**Mac Agent**:
1. Pass `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in `ClaudeCodeRunner` process env
2. Parse `tool_use_result` structured data for:
   - `TeamCreate` results → extract team_name, lead_agent_id
   - `Task` results where `status == "teammate_spawned"` → extract teammate metadata
   - `SendMessage` results → extract success, target
3. New `ServerMessage` cases: `.teamCreated(...)`, `.teammateSpawned(...)`, `.teamMessage(...)`
4. Start polling `~/.claude/teams/{name}/inboxes/team-lead.json` every 1.5s when team is active
5. New `ServerMessage` case: `.teammateInboxUpdate(messages: [...])` — forward inbox contents to iOS
6. Poll `~/.claude/teams/{name}/config.json` for member list changes

**CloudeShared models**:
```swift
struct TeamInfo: Codable {
    let name: String
    let description: String
    let leadAgentId: String
    let createdAt: Date
}

struct TeammateInfo: Codable, Identifiable {
    let id: String          // agent_id
    let name: String
    let agentType: String
    let model: String
    let color: String
    var status: TeammateStatus  // spawning → working → idle → shutdown
    var lastMessage: String?
    var lastMessageAt: Date?
}

enum TeammateStatus: String, Codable {
    case spawning, working, idle, shutdown
}

struct TeamInboxMessage: Codable {
    let from: String
    let text: String
    let summary: String?
    let timestamp: Date
    let color: String?
    let read: Bool?
}
```

**iOS**:
1. `ConversationOutput` gets `teamInfo: TeamInfo?` and `teammates: [TeammateInfo]`
2. `ConnectionManager` handles new ServerMessage types, updates team state
3. New `TeamOrbsView` — floating colored circles along right edge
4. New `TeammateCardPopover` — tap orb to see details
5. Team tool pills get special icons/colors in `ChatView+ToolPill.swift`

**Files to modify**:
- `Cloude Agent/Services/ClaudeCodeRunner+Streaming.swift` — parse team events
- `Cloude Agent/Services/RunnerManager.swift` — team state tracking + inbox polling
- `Cloude Agent/App/Cloude_AgentApp.swift` — wire team events to WebSocket
- `CloudeShared/.../ServerMessage.swift` + encoding — new message types
- `CloudeShared/.../` — new TeamInfo/TeammateInfo models
- `Cloude/Services/ConnectionManager.swift` — handle team messages
- `Cloude/Models/Conversation.swift` — team state on output
- `Cloude/UI/ChatView+ToolPill.swift` — team pill styling
- `Cloude/UI/TeamOrbsView.swift` — NEW: floating orbs overlay
- `Cloude/UI/TeammateCardPopover.swift` — NEW: orb tap detail

### Phase 2: Team Banner + Message Timeline
**Goal**: Team header banner + full dashboard sheet

1. `TeamBannerView` — slim bar below header with dots + cost
2. `TeamDashboardSheet` — full team view with:
   - Teammate cards grid
   - Message timeline (from polled inbox data)
   - Cost breakdown per model
3. Status transitions: detect `idle_notification` and `shutdown_approved` from inbox messages to update teammate status

### Phase 3: Team Interaction
**Goal**: Send messages and commands to teammates from iOS

1. "Message teammate" action in popover → injects user message to lead like "Tell scanner to ..."
2. "Shutdown teammate" → injects "Shut down scanner"
3. "Broadcast" → injects "Tell all teammates to ..."
4. These are user messages the lead interprets (no direct teammate control)

### Phase 4: Advanced
- Read `~/.claude/tasks/{team-name}/` for shared task board visualization
- Team templates / presets
- Teammate session file reading for actual work output (if possible)
- Sound effects for team events (spawn chime, message ping, shutdown)

## Constraints
- No nested teams (teammates can't spawn their own teams)
- One team per lead session (multiple conversations = multiple teams)
- Lead is fixed for team lifetime
- All teammates inherit `--dangerously-skip-permissions`
- Teammates load CLAUDE.md automatically
- `/resume` doesn't restore in-process teammates — teams are ephemeral per session
- Inbox polling adds disk I/O — keep interval reasonable (1.5-2s)

## Cost Awareness
- Each teammate = separate Claude Code instance = separate context window
- A trivial 2-teammate test cost ~$0.10 (Haiku lead + teammates)
- Real Opus work: easily $5-20+ per team session
- Cost visibility per-teammate is non-negotiable — show it prominently
