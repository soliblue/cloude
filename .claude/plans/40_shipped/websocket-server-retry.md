# WebSocket Server Retry on Port Conflict {arrow.clockwise.circle}
<!-- priority: 10 -->
<!-- tags: agent, connection -->
<!-- build: 56 -->

> Added auto-retry with increasing delay for port binding conflicts and SIGKILL-based agent restarts.

## Files
- `Cloude/Cloude Agent/Services/WebSocketServer.swift` - retry logic in `start()` + `retryStartIfNeeded()`
- `fastlane/Fastfile` - `pkill -9` and `sleep 3`

## Notes
- Root cause: old agent didn't release port 8765 fast enough after SIGTERM
- Xcode worked because debugger uses SIGKILL and waits for full exit
- Deployed Build 34, 2026-02-06
