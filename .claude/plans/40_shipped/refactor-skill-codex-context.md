---
title: "Refactor Skill: Pass Context to Codex"
description: "Improved refactor skill by passing context to Codex and enforcing sequential execution."
created_at: 2026-02-07
tags: ["refactor", "skills"]
icon: doc.text.magnifyingglass
build: 43
---


# Refactor Skill: Pass Context to Codex
## Summary
Improved the refactor skill's Codex integration in two ways:
1. Pass the skill.md path to Codex so it reads the analysis criteria and philosophy
2. Enforce sequential execution (one analyzes, the other reviews) instead of parallel

## Changes
- `.claude/skills/refactor/SKILL.md` — updated Codex prompt to reference the skill file, added Option A/B sequential ordering
