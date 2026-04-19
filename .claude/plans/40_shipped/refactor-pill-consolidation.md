---
title: "Pill Style Consolidation"
description: "Consolidated shared pill styles into PillStyles.swift, deduplicating SkillPill and SlashCommandBubble."
created_at: 2026-02-06
tags: ["refactor", "tool-pill"]
icon: capsule
build: 36
---


# Pill Style Consolidation
## Changes
- Created `PillStyles.swift` with shared `skillGradient`, `builtInGradient`, `SkillPillBackground`
- `SkillPill` and `SlashCommandBubble` now use shared styles (were copy-pasted)
- `FilePill` now uses `fileIconName()` instead of its own limited switch

## Test
- Skill pills in slash command suggestions look the same
- Slash command bubbles in chat messages look the same
- File suggestion pills show correct icons for all file types
