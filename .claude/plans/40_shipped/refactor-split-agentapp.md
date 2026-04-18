---
title: "Split Cloude_AgentApp.swift"
description: "Split 526-line AgentApp into 3 focused files for command parsing, message handling, and setup."
created_at: 2026-02-06
tags: ["agent", "refactor"]
icon: scissors
build: 36
---


# Split Cloude_AgentApp.swift {scissors}
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
