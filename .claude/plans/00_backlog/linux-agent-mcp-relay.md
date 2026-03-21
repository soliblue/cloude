# Linux Agent: Adapt Relay for MCP iOS Control {server.rack}
<!-- priority: 6 -->
<!-- tags: relay, agent -->

> Linux relay needs to forward mcp__ios__* tool calls to iOS instead of intercepting them.

The Mac agent no longer intercepts `cloude` CLI commands. iOS now handles `mcp__ios__*` tool calls directly from the stream. When Medina pulls latest, its relay needs to pass these tool calls through to iOS correctly.

## Desired Outcome
Linux relay forwards `mcp__ios__*` tool calls to iOS the same way the Mac agent does - no interception, just broadcast. The old `cloude` command parsing can be removed from the Linux side too.

**Files:** Linux agent relay code (on Medina)
