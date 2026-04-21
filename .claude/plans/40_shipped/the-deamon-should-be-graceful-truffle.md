# Menubar-only macOS daemon

## Context

The v2 macOS daemon currently launches as a regular windowed Mac app: dock icon, a `WindowGroup` holding `ContentView`, and `LSUIElement = NO` in build settings. The user wants it to be a menubar-only agent (no dock icon, icon in the status bar, click to reveal UI). The old `main` branch did this with an `NSApplicationDelegate` + `NSStatusItem` + `NSPopover`, but that's heavy for what we need. Since the deployment target is macOS 13, the simplest modern path is SwiftUI's native `MenuBarExtra` scene — no AppDelegate, no status item wiring, just a scene type.

## Approach

Use `MenuBarExtra(...) { ... }` with `.menuBarExtraStyle(.window)` so clicking the status icon shows a popover-style window hosting the existing `ContentView`. Flip the build setting `LSUIElement = YES` so the app has no dock presence.

## Changes

### 1. `daemons/macos/src/UI/macOSDaemonApp.swift`

Replace the `WindowGroup` with a `MenuBarExtra`:

```swift
import SwiftUI

@main
struct MacOSDaemonApp: App {
    var body: some Scene {
        MenuBarExtra("Cloude", systemImage: "cloud.fill") {
            ContentView()
        }
        .menuBarExtraStyle(.window)
    }
}
```

- `systemImage`: pick an SF Symbol (`cloud.fill` matches the product). Trivial to change later.
- `.menuBarExtraStyle(.window)` gives a popover-like panel that can host arbitrary SwiftUI (what `ContentView` currently is). The default `.menu` style only renders `Menu`-compatible content.
- `ContentView` stays as-is; may want to give it a fixed `.frame(width: 320, height: 360)` so the popover sizes sanely, but that's a follow-up tweak, not required.

### 2. `daemons/macos/macOSDaemon.xcodeproj/project.pbxproj`

Flip both occurrences:

```
INFOPLIST_KEY_LSUIElement = NO;  →  INFOPLIST_KEY_LSUIElement = YES;
```

This is what removes the dock icon and makes the process an "agent" app. With `MenuBarExtra` + `LSUIElement = YES`, there is no hidden main window and no dock entry — just the menubar icon.

Nothing else needs to move. `HTTPServer` and handlers keep running on app launch exactly as they do today.

## Files touched

- `daemons/macos/src/UI/macOSDaemonApp.swift` — scene swap
- `daemons/macos/macOSDaemon.xcodeproj/project.pbxproj` — `LSUIElement = YES` (Debug + Release)

## Why not the AppDelegate + NSStatusItem route

The old `main` branch used `@NSApplicationDelegateAdaptor` + `NSStatusItem` + `NSPopover` + `NSApp.setActivationPolicy(.accessory)`. That was needed before macOS 13. We're targeting 13.0, so `MenuBarExtra` replaces all of it with one scene and one build flag. Less code, no imperative AppKit, no delegate lifecycle.

## Verification

1. Build and run the `macOSDaemon` scheme from Xcode.
2. Expect: no dock icon appears; a cloud SF Symbol shows in the system menubar.
3. Click the menubar icon → the existing `ContentView` renders in a popover.
4. `curl -H "Authorization: Bearer <token>" http://localhost:8765/...` still responds — confirms `HTTPServer` came up despite the UI change.
5. Quit via the menubar popover (or `killall macOSDaemon`) and confirm process exits cleanly.
