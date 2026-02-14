# Split GlobalInputBar.swift
<!-- priority: 10 -->
<!-- tags: input, refactor -->
<!-- build: 56 -->

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
