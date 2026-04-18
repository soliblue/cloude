---
title: "Scribe Agent"
description: "Introduce scribe: a dedicated agent for committing, pushing, and managing plan lifecycle."
created_at: 2026-04-18
tags: ["agent", "git"]
icon: pencil.and.list.clipboard
build: 155
---
# Scribe Agent {pencil.and.list.clipboard}

Replaced the `push` and `plan` skills with a single `scribe` agent that owns both git history (commits + push) and plan history (ticket stage transitions). Deleted `.claude/skills/push/skill.md` and `.claude/skills/plan/skill.md`. Renamed `40_done/` to `40_shipped/` throughout to reflect the philosophy that nothing is ever done.
