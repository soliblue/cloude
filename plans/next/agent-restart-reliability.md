# Agent Restart Reliability {arrow.triangle.2.circlepath}

> Fix Mac agent restart so it works reliably even when an Xcode debug instance was running.

## Problem

When the agent is running from Xcode (debug build) and we rebuild via `fastlane mac build_agent`, the iOS app can't connect afterward. Works fine when no Xcode instance was running first.

## Root Cause (to confirm)

Multiple hypotheses — need to diagnose at laptop:

1. **Firewall/local network permission mismatch** — Xcode-signed binary vs fastlane-signed binary have different code signatures. macOS firewall prompt may appear silently on the Mac with no one to approve it.
2. **`pkill -9` skips cleanup** — NWListener socket doesn't get properly cancelled, leaving messy state even with `allowLocalEndpointReuse`.
3. **Xcode relaunch** — Xcode may try to reattach/relaunch the killed debug process.
4. **Two .app paths, same bundle ID** — DerivedData path vs build/ path may confuse macOS subsystems.

## Diagnosis Steps (at laptop)

- Check Console.app / agent.log after a failed restart to see if port bind fails or firewall blocks
- Check if a macOS firewall dialog appeared
- Run `lsof -i :8765` after the restart to see who holds the port
- Check if Xcode relaunched the process after pkill

## Approach

### 1. Graceful shutdown before kill (Fastfile)
Replace `pkill -9` with `pkill -TERM` first, wait 2s, then fall back to `-9`:
```ruby
sh("pkill -TERM -x 'Cloude Agent' || true")
sh("sleep 2")
sh("pkill -9 -x 'Cloude Agent' || true")
sh("sleep 2")
```

### 2. Self-dedup on launch (WebSocketServer or AppDelegate)
On launch, before binding the port, try connecting to localhost:8765. If something responds, send a shutdown command, wait for it to close, then proceed.

### 3. Log code signing identity on launch
Add a startup log line with the build config and code signing identity so we can diagnose firewall issues from logs alone.

## Files
- `fastlane/Fastfile` — kill sequence
- `Cloude/Cloude Agent/Services/WebSocketServer.swift` — self-dedup, logging
- `Cloude/Cloude Agent/App/Cloude_AgentApp.swift` — startup logging

## Open Questions
- Is the root cause actually firewall, port, or Xcode relaunch? Need diagnosis first.
- Should we also handle the iOS app side (more aggressive reconnect)?
