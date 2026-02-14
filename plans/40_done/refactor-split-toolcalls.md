# Split ChatView+ToolCalls.swift
<!-- priority: 10 -->
<!-- tags: refactor, tools -->
<!-- build: 56 -->

## Changes
856 lines → 4 files:
- `FileIconUtilities.swift` (113 lines) - file icon mappings
- `BashCommandIcons.swift` (246 lines) - bash/git/npm/docker icon maps
- `BashCommandParser.swift` (166 lines) - command parsing logic
- `ChatView+ToolCalls.swift` (332 lines) - ToolCallLabel + toolCallColor

## Test
- Tool pills show correct icons for: Read, Write, Edit, Bash, Glob, Grep, Task, Skill
- Bash pills show correct subcommand icons (git commit, npm install, etc.)
- Chained commands (&&) display correctly
- Tool pill colors are correct
