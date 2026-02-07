# Codex Skill

## Summary
Add a `/codex` skill to get second opinions from OpenAI's Codex CLI on code questions.

## Implementation
- Created `.claude/skills/codex/SKILL.md`
- Runs `codex exec -s read-only -C <project-root> "<question>"`
- Read-only sandbox prevents Codex from modifying files
- Codex can read the full codebase for context-aware answers
- Aliases: `/ask-codex`, `/openai`, `/second-opinion`

## Status
Done - skill created and tested successfully.
