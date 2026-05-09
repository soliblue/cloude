---
title: "Codex Agent Config Sync"
description: "Align Codex agent TOML files with the current Claude agent workflow."
created_at: 2026-05-10
updated_at: 2026-05-10
tags: ["agent"]
icon: arrow.triangle.2.circlepath
---

# Codex Agent Config Sync

## Implementation

Codex agent TOML files now mirror the current Claude-agent responsibilities for planner, launcher, tester, analyst, solver, reviewer, deployer, and scribe. The shared guidance now records that `AGENTS.md` symlinks to `CLAUDE.md`, `.codex/skills` points at `.claude/skills`, and `.codex/agents` is generated from `.claude/agents`.

## Verify

- Compare `.codex/agents/*.toml` against the corresponding `.claude/agents/*.md` responsibilities.
- Confirm the scribe config names the current plan stages as `1_next`, `2_active`, and `3_shipped`.
- Confirm no Codex agent config still references old `20_active`, `30_testing`, or `40_shipped` plan directories.
