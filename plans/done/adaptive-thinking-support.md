# Adaptive Thinking Support {brain.head.profile}
<!-- priority: 10 -->
<!-- tags: input -->
<!-- build: 56 -->

> Expose effort level controls for Opus 4.6 adaptive thinking, letting users pick low/medium/high/max per conversation or message.

Expose Claude Opus 4.6's adaptive thinking effort levels in Cloude, letting users control how hard Claude thinks per request.

## Background

Opus 4.6 (released 2026-02-05) introduces **adaptive thinking** — 4 effort levels (`low`, `medium`, `high`, `max`) replacing the old binary extended thinking toggle. The model dynamically decides reasoning depth based on task complexity, but users can override via an `effort` API parameter.

### Pricing Impact
- Same per-token price as Opus 4.5: **$5/MTok input, $25/MTok output**
- But higher effort = more thinking tokens = higher cost per request
- `low` effort on simple tasks could save significant tokens vs default `high`

### Key Facts
- Default effort level: `high`
- API parameter: `effort` in `output_config` (values: `low`, `medium`, `high`, `max`)
- `max` is Opus 4.6 only — other models return error
- Opus 4.5 uses manual thinking (`budget_tokens`), Opus 4.6 uses adaptive thinking
- `budget_tokens` is deprecated on Opus 4.6, still functional but will be removed
- Effort affects ALL tokens: text, tool calls, and thinking
- Lower effort = fewer tool calls, less preamble, more terse
- Higher effort = more tool calls, plans before acting, detailed summaries

### CLI Support (verified 2026-02-05)
- **`/effort` slash command** exists in Claude Code CLI to change effort mid-session
- **`MAX_THINKING_TOKENS` env var** — ignored on Opus 4.6 (adaptive controls it), EXCEPT `MAX_THINKING_TOKENS=0` still disables thinking entirely
- **`alwaysThinkingEnabled`** in settings.json — currently set to `true` in our config
- **Option+T / Alt+T toggle** — disables thinking entirely
- No `--effort` CLI flag found — must use `/effort` command or API-level config

### Effort Level Behavior

| Level | Thinking | Tool Calls | Use Case |
|-------|----------|------------|----------|
| `max` | Deepest, no constraints | Most thorough | Hardest problems (Opus 4.6 only) |
| `high` | Almost always thinks | Standard | Default — complex reasoning, coding, agentic |
| `medium` | May skip for simple tasks | Fewer | Balanced speed/quality for agentic tasks |
| `low` | Skips for simple tasks | Fewest, terse | Speed/cost optimization, subagents, classification |

## Goals
- Let users pick an effort level per conversation or per message
- Show estimated token impact so users understand cost tradeoffs
- Sensible defaults (keep `high` as default, match API)

## Approach

### Recommended: Per-conversation default with per-message override
- Effort level picker in window/conversation settings (default: `high`)
- Small brain icon in input bar showing current level, tappable to change per-message
- Visual indicator: brain icon with 1-4 dots/bars for level

### Implementation Path
1. Add effort level enum to shared models
2. Store effort level per conversation in `Conversation` model
3. Pass effort to CLI — likely via `/effort` command at session start, or via `--append-system-prompt` hinting
4. Input bar toggle for per-message override
5. Relay current effort level from Mac agent to iOS

### CLI Integration Options
- **Option A**: Send `/effort low` command before user messages — simplest, uses built-in CLI support
- **Option B**: Set env var or settings when spawning CLI process — more reliable but less dynamic
- **Option C**: Use `--append-system-prompt` to instruct Claude on effort — hacky, not recommended

## Files
- `Cloude Agent/Services/ClaudeCodeRunner.swift` — pass effort to CLI process
- `Cloude/UI/GlobalInputBar.swift` — effort level toggle
- `Cloude/Models/Conversation.swift` — store effort level per conversation
- `Cloude/UI/WindowEditForm.swift` — effort picker in conversation settings
- `CloudeShared/` — shared effort level enum

## Notes
- Long context (>200K tokens) pricing doubles input cost — effort level compounds with this
- Batch API gets 50% discount on thinking tokens too
- `max` effort is Opus 4.6 only — need to handle gracefully for other models
- Adaptive thinking auto-enables interleaved thinking (thinking between tool calls)
