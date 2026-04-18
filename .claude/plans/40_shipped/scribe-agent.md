# Scribe Agent {pencil.and.list.clipboard}
<!-- priority: 7 -->
<!-- tags: agent, git -->
> Introduce scribe: a dedicated agent for committing, pushing, and managing plan lifecycle.

Replaced the `push` and `plan` skills with a single `scribe` agent that owns both git history (commits + push) and plan history (ticket stage transitions). Deleted `.claude/skills/push/skill.md` and `.claude/skills/plan/skill.md`. Renamed `40_done/` to `40_shipped/` throughout to reflect the philosophy that nothing is ever done.
