# Stale Connection Watchdog

WebSocket connections silently die when the phone switches networks (wifi/cellular). Neither side detects it. The app shows "connected" and waits forever for a response that will never come. File browser empty, git tab stuck, chat hanging. Reconnecting manually fixes it.

**Note (2026-03-15):** This issue does not reproduce when connecting via Cloudflare Tunnels (current setup). Only relevant when connecting directly over the machine's IP address on the same wifi. Since tunnels are the primary connection method now, deprioritized to backlog.

## Goals
- Detect stale connections when the app sends ANY request and gets no response
- Auto-reconnect without ping/pong (no relay changes)
- Covers all request types: chat, file browser, git status, transcription, etc.

## Approach
Add a `lastMessageReceived` timestamp and a `watchdogTask` to `EnvironmentConnection`. The watchdog triggers on every `send()` since ALL requests (listDirectory, getFile, gitStatus, gitDiff, sendChat, transcribe, getProcesses, etc.) flow through `EnvironmentConnection.send()`.

Key logic:
- `receiveMessage` success path: update `lastMessageReceived = Date()`
- `send()`: if authenticated, cancel previous watchdog, schedule new one: `Task.sleep(15s)` then check if `lastMessageReceived` is still older than 15s. If so, call `handleDisconnect()` + `reconnect()`
- The watchdog checks the timestamp, not a flag, so any received message (from any source) satisfies it
- Multiple rapid sends (e.g. file browser listing + git status) share one watchdog (latest wins)
- 15s timeout: fast enough to not feel stuck, long enough for slow responses

## Files
- `EnvironmentConnection.swift` - add `lastMessageReceived: Date`, `watchdogTask: Task<Void, Never>?`, watchdog logic in `send()` and `receiveMessage`
- `EnvironmentConnection+MessageHandler.swift` - remove git-specific `gitStatusTimeoutTask` / `sendNextGitStatusIfNeeded` timeout logic (the general watchdog covers it)

## Edge Cases
- Agent running for minutes without output: not a problem because Claude streams output continuously. 15s of silence during an active run means the connection is dead
- Auth flow: watchdog should only activate after authentication (not during the auth handshake)
- Disconnect cleanup: cancel watchdog in `disconnect()`
