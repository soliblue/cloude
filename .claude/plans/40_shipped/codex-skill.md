---
title: "Codex Skill"
description: "Created /codex skill to get second opinions from OpenAI's Codex CLI in read-only sandbox mode."
created_at: 2026-02-07
tags: ["skills"]
icon: terminal
build: 43
---


# Codex Skill {terminal}
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
