# Skill Icon in Slash Command Bubbles

Skill slash commands (e.g. `/deploy`, `/image`) showed a generic `command` SF Symbol when rendered as bubbles in chat, even though the autocomplete suggestions showed the correct custom icon.

## Changes
- `MessageBubble` now accepts a `skills` parameter and looks up the skill's custom icon by name
- Falls back to `"command"` if no matching skill is found (built-in commands still use their hardcoded icons)
- `SwipeToDeleteBubble` also passes skills through for queued slash commands

## Files
- `ChatView+MessageBubble.swift` — added `skills` param, icon lookup in `slashCommandInfo`
- `ConversationView+Components.swift` — pass `connection?.skills` to both bubble types
