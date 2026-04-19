---
title: "Terminal Exec - Mac Agent"
description: "Add terminalExec message handler to Mac agent for feature parity with Linux relay."
created_at: 2026-03-10
tags: ["agent"]
icon: terminal.fill
build: 82
---


# Terminal Exec - Mac Agent
## Changes
- `AppDelegate+MessageHandling.swift`: Added `terminalExec` case routing to handler
- `Cloude_AgentApp+Handlers.swift`: Implemented `handleTerminalExec` - spawns bash process, captures stdout/stderr, returns `terminalOutput` response
