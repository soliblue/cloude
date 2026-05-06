# Debug log upload infra

## Goal

Ship a one-tap path for sending the iOS app's `app-debug.log` from a real device to the Mac daemon, so on-device perf/debug investigations don't require tethering or the Simulator.

## Product shape

- `DebugOverlay` (currently a top-trailing FPS pill when `debugOverlayEnabled`) becomes tappable.
- Tap expands it in place into a small panel with:
  - FPS (already shown)
  - "Send logs to server" button
- Button POSTs the contents of `AppLogger.logFileURL` to the current session's endpoint daemon.
- Daemon overwrites `~/Library/Application Support/Cloude/ios-logs/latest.log` so the path is stable and agents can `Read` it without hunting for timestamps.
- Success/failure surfaced as a brief state flip on the button (checkmark / xmark).

## Files

- `clients/ios/src/Core/Debug/DebugOverlay.swift` — add `@State private var expanded: Bool`, expand on tap, show button.
- `clients/ios/src/Core/Debug/DebugLogUploader.swift` — stateless helper. Reads `AppLogger.logFileURL`, POSTs to `<endpoint>/debug/ios-log` via `HTTPClient`.
- `daemons/macos/src/Handlers/DebugHandler.swift` — new handler. `POST /debug/ios-log` writes request body to `~/Library/Application Support/Cloude/ios-logs/latest.log`, returns `{"ok": true, "path": "..."}`. Ensures parent dir exists.
- `daemons/macos/src/Routing/Router.swift` — wire the new route.

## Notes

- `HTTPClient` already resolves the auth token per endpoint; the uploader just calls its POST helper.
- `DebugOverlay` has no other consumers, so making it expandable is self-contained.
- Overwrite-latest (not timestamped) is deliberate: agents read one known path. A future upgrade can add an index route.

## Out of scope

- Zipping, streaming upload, chunking (log is tiny today).
- Pulling daemon-side logs to iOS (other direction).
- Authentication beyond what `HTTPClient` already does.

## Done when

- Real-device tap lands the log at `~/Library/Application Support/Cloude/ios-logs/latest.log`.
- An agent can `Read` that path and see the same contents as the device's `app-debug.log`.
