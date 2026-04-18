---
title: "Fix abort race condition in linux-relay"
description: "Fixed race condition where pressing stop on iOS could leave two agents running simultaneously by making abort await process exit before spawning new ones."
created_at: 2026-03-10
tags: ["relay", "connection"]
icon: bolt.trianglebadge.exclamationmark
build: 82
---


# Fix abort race condition in linux-relay {bolt.trianglebadge.exclamationmark}
## Problem
Pressing stop on iOS didn't reliably kill the Claude process. If a new message was sent before the old process died, two agents would run simultaneously in the same session. The old process dying also broadcast a false `idle` status, confusing the iOS UI.

## Solution
- `abort()` returns a Promise, resolved on process exit (or 5s timeout)
- Kill escalation: SIGINT -> SIGTERM (2s) -> SIGKILL (5s)
- `run()` awaits old process exit before spawning new one
- `superseded` flag prevents killed processes from broadcasting false idle

## Files Changed
- `linux-relay/runner.js`
