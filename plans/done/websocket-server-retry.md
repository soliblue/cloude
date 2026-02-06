# WebSocket Server Retry on Port Conflict

Agent auto-retries port binding up to 5 times with increasing delay (2s, 4s, 6s, 8s, 10s) when "address already in use". Fastlane deploy now uses SIGKILL + 3s wait for clean agent restarts.

## Files
- `Cloude/Cloude Agent/Services/WebSocketServer.swift` - retry logic in `start()` + `retryStartIfNeeded()`
- `fastlane/Fastfile` - `pkill -9` and `sleep 3`

## Notes
- Root cause: old agent didn't release port 8765 fast enough after SIGTERM
- Xcode worked because debugger uses SIGKILL and waits for full exit
- Deployed Build 34, 2026-02-06
