---
title: "Pass effort as --effort CLI flag"
description: "Fixed effort level to pass as --effort CLI flag instead of /effort prompt prefix."
created_at: 2026-03-15
tags: ["agent", "relay"]
icon: slider.horizontal.3
build: 86
---


# Pass effort as --effort CLI flag {slider.horizontal.3}
Effort level was prepended to the prompt as `/effort <level>`, which Claude Code interpreted as a slash command ("effort is not a skill"). Fixed to pass as `--effort <level>` CLI flag, matching how `--model` is already handled.

## Changes
- **Mac agent**: `ClaudeCodeRunner.swift` - removed `/effort` prompt prefix, added `--effort` to command args
- **Linux relay**: `runner.js` - same fix

**Files:** `Cloude Agent/Services/ClaudeCodeRunner.swift`, `linux-relay/runner.js`
