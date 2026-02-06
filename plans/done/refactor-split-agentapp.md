# Split Cloude_AgentApp.swift

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
