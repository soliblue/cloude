# Plan: v2 launcher rewrite for autonomous loops

## Context

The existing `launcher` subagent + `start-local-simulator.sh` belong to v1: they reference `fastlane mac build_agent`, `com.cloude.agent` Keychain service, `cloude://environment/select` deep-link, a `finish name=environment.auth` log marker, and an `environments.json` schema with `token`/`symbol` fields — none of which exist in v2.

Goal: a launcher Claude can invoke fully autonomously as part of pickup-ticket → implement → launch → test loops. No human paste, no manual sim setup. Must work from a cold state (daemon not running, sim not booted, app not installed) and be idempotent on repeat runs.

The hard problem is seeding the iOS app's auth token. v2 stores auth keys in the iOS Keychain under service `soli.Cloude.environments`, account = endpoint UUID. Simulator Keychain is sandboxed per-sim and not writable from the host for app-scoped items. Three options:

- **(A) DEBUG env-var seed** — app reads `CLOUDE_DEV_*` vars at launch (`#if DEBUG`), upserts a dev endpoint, writes token to Keychain. Host passes via `xcrun simctl launch --env`.
- (B) File drop in sim container — launcher writes `Documents/dev-seed.json`, app reads+deletes on first launch.
- (C) `simctl keychain add-generic-password` — unreliable for app-scoped items, flaky across Xcode versions.

Going with **(A)**. Smallest code surface in the app, no filesystem cleanup, no Keychain-from-host dance. Env vars are only set when launched via `simctl launch`, so user-launched runs from the home screen are unaffected.

## Scope

1. One small iOS code change: a DEBUG-only seed in `EndpointsStore.init`.
2. Rewrite `.claude/agents/launcher.md` to match v2.
3. Rewrite `.claude/agents/launcher/start-local-simulator.sh` end-to-end.
4. Delete `.claude/agents/launcher/dismiss-sim-alerts.sh` (no longer needed — no consent prompts in v2).
5. Also fix the `cloude://` `CFBundleURLSchemes` entry in iOS `Info.plist` — dead registration with no handler. Remove it.

Out of scope: a full in-app logger, a ready-marker protocol, XCUI harness, multi-sim parallel launches. Downstream testers can probe readiness by curling the daemon directly.

## iOS change

### `clients/ios/src/Features/Endpoints/Logic/EndpointsStore.swift`

Add to `init()`, after the load block:

```swift
#if DEBUG
let env = ProcessInfo.processInfo.environment
if let token = env["CLOUDE_DEV_TOKEN"],
   let host = env["CLOUDE_DEV_HOST"],
   let portString = env["CLOUDE_DEV_PORT"], let port = Int(portString),
   let idString = env["CLOUDE_DEV_ENV_ID"], let id = UUID(uuidString: idString) {
    SecureStorage.set(account: id.uuidString, value: token)
    if let index = endpoints.firstIndex(where: { $0.id == id }) {
        endpoints[index].host = host
        endpoints[index].port = port
    } else {
        endpoints.append(Endpoint(id: id, host: host, port: port))
    }
}
#endif
```

Idempotent across relaunches. Writes Keychain on every launch (cheap, overwrites with same value if unchanged). Doesn't touch `status`.

### `clients/ios/src/Info.plist`

Remove the `CFBundleURLTypes` / `CFBundleURLSchemes` `cloude` entry — registered but no handler exists, so it's dead config.

## Launcher script

### `.claude/agents/launcher/start-local-simulator.sh`

Flags: `[--device <name>] [--skip-daemon]`. Exit non-zero with `failed: <phase>, <reason>` on any failure.

Pipeline:

1. **Resolve sim.** Newest-iOS iPhone from `xcrun simctl list devices available -j`; prefer already-booted. Respect `--device`.
2. **Build daemon.** `xcodebuild -project daemons/macos/macOSDaemon.xcodeproj -scheme 'Cloude Agent' -configuration Debug -derivedDataPath /tmp/cloude-daemon-build build`. Stable path → `/tmp/cloude-daemon-build/Build/Products/Debug/Remote CC Daemon.app`. Skip if `--skip-daemon`.
3. **Kill any running daemon,** relaunch: `pkill -9 -f 'Remote CC Daemon'; open <app>`.
4. **Poll host Keychain** for token: `security find-generic-password -s soli.Cloude.agent -a authToken -w`, up to 10s. Daemon generates on first launch and reuses thereafter.
5. **curl-verify daemon:** `curl -sS -H "Authorization: Bearer $TOKEN" http://127.0.0.1:8765/ping` must return `{"ok":true,...}`. Catches port conflicts and token-regen edge cases before touching the sim.
6. **Boot sim** (if not already booted) and `open -a Simulator --args -CurrentDeviceUDID <udid>`.
7. **Build iOS app.** `xcodebuild -project clients/ios/iOS.xcodeproj -scheme Cloude -destination "platform=iOS Simulator,id=<udid>" -derivedDataPath /tmp/cloude-ios-build build`.
8. **Install:** `xcrun simctl install <udid> <app>`.
9. **Launch with env injection:**
   ```
   xcrun simctl launch --terminate-running-process \
     --env CLOUDE_DEV_TOKEN=$TOKEN \
     --env CLOUDE_DEV_HOST=127.0.0.1 \
     --env CLOUDE_DEV_PORT=8765 \
     --env CLOUDE_DEV_ENV_ID=c10de51d-5151-4551-8551-0000000c10de \
     <udid> soli.Cloude
   ```
10. **Emit ready line:**
    ```
    ready: sim=<udid> bundle=soli.Cloude daemon_pid=<pid> token=<token> host=127.0.0.1 port=8765 env_id=<id>
    ```

### `.claude/agents/launcher.md`

Match the new pipeline. Drop references to `environments.json` seeding, deep links, `finish name=environment.auth` readiness marker. Phases: `build_daemon | launch_daemon | token | daemon_probe | boot | build_ios | install | launch`.

### Delete

- `.claude/agents/launcher/dismiss-sim-alerts.sh` — no consent prompts in v2.

## Critical files

- `clients/ios/src/Features/Endpoints/Logic/EndpointsStore.swift` (add DEBUG seed)
- `clients/ios/src/Info.plist` (remove dead URL scheme)
- `.claude/agents/launcher.md` (rewrite)
- `.claude/agents/launcher/start-local-simulator.sh` (rewrite)
- `.claude/agents/launcher/dismiss-sim-alerts.sh` (delete)

## Verification

1. From a cold state (`pkill -9 -f 'Remote CC Daemon'`), run the launcher. Must print a `ready:` line within ~60s.
2. The iOS sim app must open directly showing a connected (green) endpoint pointing at `127.0.0.1:8765` without any user interaction.
3. Re-run: no duplicate endpoint created; same dev UUID is updated in-place.
4. `curl -H "Authorization: Bearer <token>" http://127.0.0.1:8765/ping` still returns 200.
5. Build in release/Xcode run: no dev endpoint seeded (only DEBUG).
6. Launch the sim app manually from the home screen (no `--env`): store loads from disk, no seed written, existing data untouched.
