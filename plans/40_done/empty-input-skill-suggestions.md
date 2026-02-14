# Show Skill Suggestions on Empty Input

## Problem
Skills are only discoverable when typing `/` — new users or casual use misses them entirely. The input bar shows rotating placeholder text when empty, but could also surface skill pills as a discovery mechanism.

## Solution
When the input bar is empty and focused, show the `SlashCommandSuggestions` view with skill commands (not built-in commands like `/compact`). This gives users a visual menu of available capabilities without needing to know about `/`.

## Implementation

### GlobalInputBar.swift
- In `filteredCommands`, return skill-only commands when `inputText.isEmpty` and input is focused
- Or add a separate computed property `emptyStateSuggestions` that returns skills only
- Show `SlashCommandSuggestions` in the body when input is empty + focused + not running + no other overlays active

### Behavior
- Tapping a skill pill should insert `/skillname` and behave exactly like the current slash flow
- When user starts typing anything (not `/`), the suggestions disappear
- When user types `/`, switch to the existing filtered command list (includes built-ins)
- Don't show when `isRunning` (agent is working)
- Don't show when there are `suggestions` (response suggestions take priority)

### Design
- Same `SkillPill` component, same horizontal scroll
- Maybe a subtle label above like "Skills" or just the pills alone
- Consider showing only skills (not built-in commands) to keep it clean and focused on capabilities
