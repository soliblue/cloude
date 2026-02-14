# Context Window Limits
<!-- priority: 10 -->
<!-- tags: ui, windows -->
<!-- build: 56 -->

Opus 4.6 supports up to 1M tokens. Without guardrails, a single long conversation could burn through significant API costs before Claude CLI's internal compaction kicks in. We need control over context usage.

## Goals
- Warn before conversations get expensive
- Optionally cap context to prevent runaway costs

## Current State
- Cloude has **zero context management** — it's a passthrough to Claude CLI
- Claude CLI handles compaction internally, but with 1M token windows the threshold is much higher
- No visibility into token usage per conversation from the iOS side
- ResponseStore has a 50-entry / 24hr limit, but that's for crash recovery, not context

## Approach

### Warnings
- Configurable cost threshold per conversation (e.g. $5, $10, $25)
- Warning banner when approaching threshold
- Option to continue or start fresh conversation

### Hard Limits (optional)
- Max cost cap per conversation — refuses to send after threshold
- Could also cap by message count or estimated tokens
- "Start new conversation" prompt when limit hit

## Files
- `Cloude/Cloude/UI/ChatView.swift` — warning banner
- `Cloude/Cloude/Services/ConnectionManager+API.swift` — check limits before sending
- `Cloude/Cloude/UI/SettingsView.swift` — threshold configuration

## Notes
- Token counting from iOS side is approximate at best — we don't have the tokenizer
- Cost per message (`costUsd`) from the CLI stream is the most reliable signal
- Message count is a rough proxy but varies wildly by message length
- Depends on conversation cost tracking ticket for the underlying data
