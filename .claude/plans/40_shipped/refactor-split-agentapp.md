# Split Cloude_AgentApp.swift {scissors}
<!-- priority: 10 -->
<!-- tags: agent, refactor -->
<!-- build: 56 -->

> Split 526-line AgentApp into 3 focused files for command parsing, message handling, and setup.

## Changes
526 lines → 3 files (+ existing Handlers):
- `Cloude_AgentApp.swift` (194 lines) - app entry, setup
- `AppDelegate+CommandParsing.swift` (210 lines) - cloude commands
- `AppDelegate+MessageHandling.swift` (126 lines) - message routing

## Test
- Agent starts correctly (menu bar icon appears)
- cloude rename/symbol commands work
- cloude ask command renders questions
- cloude notify sends push notification
- Message routing (chat, abort, git, files) all work
