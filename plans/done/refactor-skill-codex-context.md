# Refactor Skill: Pass Context to Codex

## Summary
Improved the refactor skill's Codex integration in two ways:
1. Pass the skill.md path to Codex so it reads the analysis criteria and philosophy
2. Enforce sequential execution (one analyzes, the other reviews) instead of parallel

## Changes
- `.claude/skills/refactor/SKILL.md` — updated Codex prompt to reference the skill file, added Option A/B sequential ordering
