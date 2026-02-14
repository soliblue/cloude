# Unified Consult Skill

Merged `/codex` and `/secondbrain` into a single `/consult` skill that routes to Codex (OpenAI) or different Claude models (Haiku, Sonnet, Opus). One skill, multiple brains. All read-only.

## Changes
- Created `.claude/skills/consult/SKILL.md` with routing logic
- Removed `.claude/skills/codex/` (absorbed into consult)
- Removed `.claude/skills/secondbrain/` (absorbed into consult)
- Aliases include: ask, second-opinion, secondbrain, codex, consult-haiku, consult-sonnet, consult-opus
- Default model: Sonnet
