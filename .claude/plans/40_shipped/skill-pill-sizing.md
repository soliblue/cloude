---
title: "Skill Pill Sizing"
description: "Matched slash command bubble dimensions to inline tool pill sizing for visual consistency."
created_at: 2026-03-15
tags: ["skills", "ui"]
icon: textformat.size
build: 86
---


# Skill Pill Sizing {textformat.size}
Match SlashCommandBubble dimensions to InlineToolPill so skill pills in messages look the same size as tool pills.

## Changes
- `MessageBubble+SlashCommand.swift`: icon 14→10pt, text 12→9pt, spacing 6→4, padding 10h/6v → 8h/4v

**Files:** `MessageBubble+SlashCommand.swift`
