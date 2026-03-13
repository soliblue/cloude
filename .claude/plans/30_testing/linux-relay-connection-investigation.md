# Linux Relay Connection Investigation

## Problem
Soli sent a message from iOS, never got a response, had to restart the app. We can't tell what went wrong because logging is insufficient and the relay has process management issues.

## Timeline (2026-03-12)
1. **23:09:21** - relay crashed with `SyntaxError: \!` in server.js:59 (escaped exclamation mark)
2. **23:09:26** - systemd restarted the service (pid 150927), client connected and authenticated
3. **23:10:12** - second client connected, authenticated, then immediately disconnected (code=1002, protocol error)
4. **23:10:23 to 23:13:32** - service tried restarting 4 times, all failed with EADDRINUSE
5. **23:13:32 onward** - systemd service (pid 152327) running but never got the port, logs `clients=0` every hour

## Validated Findings

### Process Split (CONFIRMED)
- **pid 152311**: `node index.js` - owns port 8765, stdout/stderr -> /dev/null (no logging), has active sockets (Soli's current connection)
- **pid 152327**: systemd service (`/usr/bin/node /home/soli/projects/cloude/linux-relay/index.js`) - running but failed EADDRINUSE, logging to journald with 0 clients
- **pid 108862**: unrelated (agentpit server)

### Root Cause
Process 152311 was started manually (or by a previous Claude session) before the systemd service restarted. It grabbed port 8765, the systemd service couldn't bind, but both kept running. The rogue process logs to /dev/null so we have zero visibility.

### Logging Gaps
- No outgoing message logging (we log `<- msg.type` but never `-> msg.type`)
- `request_missed_response` handler is a no-op (line 110-111 in handlers.js)
- Rogue process logs nowhere because its stdout/stderr are /dev/null
- No logging inside handler functions for what they return

### Open Question
- Was the message loss an iOS-side issue (app didn't send, or dropped before relay responded)?
- Or server-side (handler crashed silently, response never sent)?
- We genuinely can't tell with current logging

## Fix Plan

### 1. Kill rogue process, restart cleanly
- Kill pid 152311
- Restart systemd service so it owns the port
- Verify with `ss -tlnp` that systemd's pid owns 8765

### 2. Add outgoing message logging
- Log `-> msg.type` in `sendTo()` and `broadcast()`
- Add response logging in key handlers (chat, abort, errors)

### 3. Prevent rogue processes
- Add `ExecStartPre` to systemd service to kill any existing process on port 8765
- Or add port conflict detection in index.js

### 4. Fix the `\!` syntax issue
- Verify it's actually fixed in the current server.js (it was - the git diff shows `!` not `\!`)

## Conclusion

Server side is clean. The problem is on iOS.

**Evidence**: Server logs show every message arriving (`<- chat`) and every response being broadcast (`=> output to N clients`) with no errors or disconnects. When Soli reports no response, the server logs show the response was sent successfully.

**iOS suspects** (from code review of EnvironmentConnection.swift):
1. `isConnected` set to `true` on `webSocket.resume()` before handshake completes - app shows "connected" but socket may not actually be working
2. Rapid reconnection can drop messages if connectionToken changes mid-receive
3. If `manager` weak ref is nil during view lifecycle, all messages silently dropped
4. Output with nil conversationId + no runningConversationId = silently discarded

**Next step**: Investigate iOS ConnectionManager when building from Xcode.

## Server Fixes Applied
- [x] Killed rogue process (152311) that was stealing port from systemd service
- [x] Added outgoing message logging (`->` sendTo, `=>` broadcast)
- [x] Added ExecStartPre to systemd service (fuser -k 8765/tcp)
- [x] Increased ping tolerance from 1 missed ping (30s) to 3 missed pings (90s)
- [x] Verified server correctly sends all responses with conversationId

## iOS Fixes Applied (2026-03-13)
Investigated all 4 iOS suspects. Fixed #1 and added resilience for #2:

- [x] **Suspect #1 (FIXED)**: `isConnected` no longer set on `webSocket.resume()`. Now deferred until server sends `auth_required` (proves TCP handshake completed). Prevents UI from showing "connected" before socket is actually open.
- [x] **Connection timeout**: If no `auth_required` within 10s, auto-reconnects instead of hanging silently.
- [x] **Send failure recovery**: If `webSocket.send()` errors, triggers `handleDisconnect()` + auto-reconnect (throttled to max once per 5s to prevent loops).
- [x] Suspect #3 (manager nil) and #4 (nil conversationId) are edge cases that can't easily be triggered in normal use - left as-is.
