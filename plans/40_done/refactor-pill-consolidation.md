# Pill Style Consolidation
<!-- priority: 10 -->
<!-- tags: refactor, tools -->
<!-- build: 56 -->

## Changes
- Created `PillStyles.swift` with shared `skillGradient`, `builtInGradient`, `SkillPillBackground`
- `SkillPill` and `SlashCommandBubble` now use shared styles (were copy-pasted)
- `FilePill` now uses `fileIconName()` instead of its own limited switch

## Test
- Skill pills in slash command suggestions look the same
- Slash command bubbles in chat messages look the same
- File suggestion pills show correct icons for all file types
