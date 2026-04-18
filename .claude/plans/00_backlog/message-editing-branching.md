---
title: "Message Editing & Conversation Branching"
description: "Allow sent messages to be edited and conversations to branch from the edited point."
created_at: 2026-03-01
tags: ["ui"]
icon: arrow.triangle.branch
build: 74
---


# Message Editing & Conversation Branching {arrow.triangle.branch}
## Goal
Edit sent messages and branch conversations — like ChatGPT's edit feature with `< 1/2 >` navigation.

## Approach
The Claude CLI stores conversations as a DAG (uuid/parentUuid) in JSONL files. `--fork-session` exists but only forks from the current leaf. To edit mid-conversation:

**Option A: JSONL leaf manipulation** — Move `leafUuid` to the message before the edit point, fork, then restore. Risk: briefly corrupts original session.

**Option B: New session with context replay** — Start fresh session, pack history up to edit point as context. Safe but loses tool call state.

**Option C: Copy JSONL + modify** — Won't work because session IDs are CLI-generated and embedded in the file.

## Phase 0: CLI Testing (MUST DO FIRST)
- Manually test if appending a summary entry with a different `leafUuid` makes `--fork-session` fork from that point
- If it doesn't work, fall back to Option B

## Phases 1-6
See full plan: `plans/adaptive-launching-truffle.md` (detailed implementation with ~370 lines across 6 phases)

## Key Files
- `Conversation.swift` — branch-aware model
- `ClientMessage.swift` / `ServerMessage.swift` — new `editMessage` / `branchCreated` types
- New `SessionForkService.swift` — JSONL manipulation on Mac agent
- `MessageBubble.swift` — edit context menu + branch nav arrows
- `GlobalInputBar.swift` — edit mode UI

## Open Questions
- Does JSONL leaf manipulation actually work? (Phase 0)
- How to handle editing the first message? (no parent to fork from)
- Should we show full branch tree or just `< 1/2 >` arrows? (start simple)
