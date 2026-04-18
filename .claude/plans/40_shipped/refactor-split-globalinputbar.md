# Split GlobalInputBar.swift {scissors}
<!-- priority: 10 -->
<!-- tags: input, refactor -->
<!-- build: 56 -->

> Split 635-line GlobalInputBar into 3 files for main bar, slash commands, and sub-components.

## Changes
635 lines → 3 files:
- `GlobalInputBar.swift` (408 lines) - main input bar
- `SlashCommand.swift` (37 lines) - command model
- `GlobalInputBar+Components.swift` (140 lines) - sub-components

## Test
- Slash command suggestions appear when typing /
- Skill pills show correct styling
- File mention suggestions (@) work
- Photo picker works from send menu
- Pending audio banner appears/dismisses
