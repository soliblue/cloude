---
title: "Android Slash Commands"
description: "Slash command autocomplete in input bar with skill suggestions."
created_at: 2026-03-28
tags: ["android", "input"]
icon: command
build: 120
---
# Android Slash Commands


## Implementation

- Skills stored on `EnvironmentConnection` when `ServerMessage.Skills` received
- `SlashCommand` model with built-in commands (compact, context, cost, usage) + dynamic skills from agent
- Horizontal pill row above input bar when typing `/`
- Prefix filtering on command names and aliases
- Tap pill to insert command; auto-sends if no parameters, stays focused if has parameters
- Skill pills styled with accent tint, built-in pills use surface variant

## Files Changed
- `Models/SlashCommand.kt` (new) - command model with filtering
- `Services/EnvironmentConnection.kt` - store skills
- `UI/chat/InputBar.kt` - suggestion pills + skill parameter
- `UI/chat/ChatScreen.kt` - pass skills to InputBar
