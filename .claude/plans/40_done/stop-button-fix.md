# Stop Button Fix {stop.fill}

> Fix stop button not working when Claude process has already finished on Linux relay

When iOS sends `abort` but the process has already exited, the relay now sends back `status: idle` instead of silently doing nothing. This unsticks the iOS app from the "running" state.

## Changes
- `linux-relay/runner.js`: `abort()` and `abortAll()` send `status: idle` when no active process exists
