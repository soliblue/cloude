# Terminal Exec - Mac Agent {terminal.fill}
<!-- priority: 10 -->
<!-- tags: agent -->

> Add terminalExec message handler to Mac agent for feature parity with Linux relay.

## Changes
- `AppDelegate+MessageHandling.swift`: Added `terminalExec` case routing to handler
- `Cloude_AgentApp+Handlers.swift`: Implemented `handleTerminalExec` - spawns bash process, captures stdout/stderr, returns `terminalOutput` response
