---
title: "Move Whiteboard To Separate MCP"
description: "Moved whiteboard tools out of the iOS MCP namespace into a dedicated whiteboard MCP without changing whiteboard behavior in the app."
created_at: 2026-03-28
tags: ["agent", "ui"]
icon: paintbrush
build: 120
---


# Move Whiteboard To Separate MCP
## Problem
Whiteboard actions were exposed through `mcp__ios__whiteboard_*`, which mixed a full canvas subsystem into the generic iOS control namespace. The feature itself was good, but the boundary was muddy and made the core iOS MCP broader than it needed to be.

## Fix
Created a dedicated `whiteboard` MCP server and moved the whiteboard tools there:
- `mcp__whiteboard__open`
- `mcp__whiteboard__add`
- `mcp__whiteboard__remove`
- `mcp__whiteboard__update`
- `mcp__whiteboard__clear`
- `mcp__whiteboard__snapshot`
- `mcp__whiteboard__export`
- `mcp__whiteboard__viewport`

Kept the native whiteboard UI, store, persistence, snapshot flow, and export flow unchanged. Updated the app to route `mcp__whiteboard__*` calls into the existing whiteboard event path and updated tool pill labeling so whiteboard tools still read correctly in chat.

**Files:** `.mcp.json`, `.claude/ios-mcp/server.js`, `.claude/ios-mcp/whiteboard-server.js`, `Cloude/Cloude/Services/EnvironmentConnection+Handlers.swift`, `Cloude/Cloude/Services/EnvironmentConnection+IOSTools.swift`, `Cloude/Cloude/UI/ToolCallLabel.swift`

## Test
- [ ] Fresh session shows whiteboard tools under `mcp__whiteboard__*`, not `mcp__ios__whiteboard_*`
- [ ] Regular iOS control tools still appear under `mcp__ios__*`
- [ ] Whiteboard tool pills still show the right labels and still open the whiteboard when tapped
- [ ] `open`, `add`, `update`, `remove`, `clear`, `snapshot`, `export`, and `viewport` all behave exactly as before
- [ ] Snapshot still sends `[whiteboard snapshot]` back into the conversation
- [ ] Export still sends `[whiteboard export]` with the rendered image back into the conversation
