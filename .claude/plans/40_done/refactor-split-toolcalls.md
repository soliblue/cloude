# Split ChatView+ToolCalls.swift {scissors}
<!-- priority: 10 -->
<!-- tags: refactor, tool-pill -->
<!-- build: 56 -->

> Split 856-line ToolCalls into 4 files for file icons, bash icons, command parsing, and more.

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
