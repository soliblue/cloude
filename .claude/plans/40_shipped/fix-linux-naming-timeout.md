---
title: "Fix: Linux relay auto-naming always timing out"
description: "Fixed Linux relay naming timeout by closing stdin and stripping CLAUDECODE env var on spawn."
created_at: 2026-03-10
tags: ["relay"]
icon: clock.badge.exclamationmark
build: 82
---


# Fix: Linux relay auto-naming always timing out
## Problem
The `handleSuggestName` handler spawned `claude --model sonnet -p ...` via `spawn('bash', ...)` without closing stdin. The Claude CLI hung waiting for stdin input, causing every naming request to hit the 15s timeout.

## Root Cause
Node's `spawn()` creates a pipe for stdin by default. The Claude CLI detects a pipe on stdin and waits for input before proceeding. The main runner (`runner.js`) already handled this with `this.process.stdin.end()`, but the naming handler didn't.

## Fix
- Set `stdio: ['ignore', 'pipe', 'pipe']` to close stdin immediately
- Strip `CLAUDECODE` env var to prevent nested-session detection
- Ensure PATH fallback for systemd environments
- Add debug logging for stderr and non-zero exit codes
