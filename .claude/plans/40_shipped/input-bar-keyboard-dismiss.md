# Dismiss keyboard on auto-send slash commands {keyboard.chevron.compact.down}
<!-- priority: 10 -->
<!-- tags: input, ui -->

> Fixed keyboard staying visible after selecting auto-send slash commands.

## Problem
When selecting a slash command that auto-sends (no parameters), the keyboard stayed visible instead of dismissing.

## Fix
Added `isInputFocused = false` before `onSend()` in `GlobalInputBar.swift` slash command selection handler.

## File changed
- `Cloude/Cloude/UI/GlobalInputBar.swift` (line 152)
