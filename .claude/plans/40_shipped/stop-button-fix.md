---
title: "Stop Button Fix"
description: "Fixed stop button by sending idle status when aborting an already-exited process on Linux relay."
created_at: 2026-03-10
tags: ["relay"]
icon: stop.fill
build: 82
---


# Stop Button Fix {stop.fill}
When iOS sends `abort` but the process has already exited, the relay now sends back `status: idle` instead of silently doing nothing. This unsticks the iOS app from the "running" state.

## Changes
- `linux-relay/runner.js`: `abort()` and `abortAll()` send `status: idle` when no active process exists
