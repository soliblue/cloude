---
title: "Dismiss keyboard on auto-send slash commands"
description: "Fixed keyboard staying visible after selecting auto-send slash commands."
created_at: 2026-02-14
tags: ["input", "ui"]
icon: keyboard.chevron.compact.down
build: 71
---


# Dismiss keyboard on auto-send slash commands {keyboard.chevron.compact.down}
## Problem
When selecting a slash command that auto-sends (no parameters), the keyboard stayed visible instead of dismissing.

## Fix
Added `isInputFocused = false` before `onSend()` in `GlobalInputBar.swift` slash command selection handler.

## File changed
- `Cloude/Cloude/UI/GlobalInputBar.swift` (line 152)
