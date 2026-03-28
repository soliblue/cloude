# Android Slash Commands {command}
<!-- priority: 9 -->
<!-- tags: android, input -->

> Slash command autocomplete in input bar with skill suggestions.

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
