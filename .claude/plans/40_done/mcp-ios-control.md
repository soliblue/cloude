# MCP iOS Control - Replace cloude CLI with MCP tools

## Summary
Replaced the `cloude` CLI command system with two MCP servers: `mcp__ios__*` for app control and `mcp__widgets__*` for rich content. iOS app now handles control tool calls directly from the stream instead of relying on Mac agent command parsing.

## Changes

### New
- `.claude/ios-mcp/` - MCP server for iOS control (rename, symbol, notify, clipboard, open, haptic, switch, delete, skip, screenshot)
- `.claude/widgets-mcp/` descriptions updated with dev-relevant use cases
- `EnvironmentConnection+Handlers.swift` - `handleIOSToolCall` intercepts `mcp__ios__*` tool calls directly on iOS

### Deleted
- `~/.local/bin/cloude` - CLI stub script
- `Cloude Agent/Services/CLIInstaller.swift` - stub installer
- `Cloude Agent/App/AppDelegate+CommandParsing.swift` - 210 lines of string parsing
- 12 dead `ServerMessage` cases (renameConversation, clipboard, notify, haptic, etc.)
- `cloude memory` and `cloude speak` commands (killed)
- All `isMemoryCommand` references in UI

### Updated
- `Cloude_AgentApp.swift` - removed `cloude` command interception from onToolCall
- `EnvironmentConnection+MessageHandler.swift` - removed 12 dead ServerMessage handlers
- `EnvironmentConnection+CommandHandlers.swift` - removed 6 dead handler functions
- `EnvironmentConnection+FileHandlers.swift` - removed handleHeartbeatSkipped, handleMemoryAdded
- `ServerMessage.swift` - removed dead enum cases and unused CodingKeys
- `CLAUDE.md` - replaced Cloude Commands section with iOS Control (MCP), added Widgets vs Extended Markdown section, slimmed Plans and Deployment sections
- `.mcp.json` - added ios MCP server, fixed widget path to relative

## Test
- [ ] Rename works via mcp__ios__rename tool call
- [ ] Symbol works via mcp__ios__symbol tool call
- [ ] Notify sends push notification
- [ ] Clipboard copies text to iOS
- [ ] Screenshot captures and returns image
- [ ] Skip works during heartbeat
- [ ] Delete removes conversation
- [ ] Auto-naming still works (Sonnet flow via nameSuggestion)
- [ ] Widgets still render (tree, timeline, charts, etc.)
- [ ] Old cloude commands no longer referenced anywhere
