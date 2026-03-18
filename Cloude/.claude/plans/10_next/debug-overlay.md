# Debug Overlay

Floating diagnostic panel for identifying bottlenecks and tracking app health. Toggled from Settings, disabled by default.

## Goals
- Real-time FPS counter to catch UI jank (especially during streaming)
- Memory + storage usage to spot leaks and bloat
- WebSocket message log to debug connection issues
- Extensible: each metric is a self-contained module

## Approach

### 1. Toggle
`@AppStorage("debugOverlayEnabled")` in Settings, default `false`. No `#if DEBUG` gate - this is user-accessible in production (useful for diagnosing issues on device).

### 2. DebugMetrics (service)
`Services/DebugMetrics.swift` - `@MainActor ObservableObject` singleton.

**FPS**: Own `CADisplayLink`, tracks frame intervals. Shows current FPS + frame time. Accounts for ProMotion (120Hz) vs 60Hz by showing percentage of target refresh rate. Pauses when `scenePhase != .active`.

**Memory**: `task_vm_info` via mach kernel API. Polls every 2s via `Task.detached`. Shows `phys_footprint` (actual RAM). Publishes on main.

**Storage**: Sums `Documents/conversations/` and `Documents/cache/` sizes. Runs on background queue every 10s (disk I/O off main). Publishes on main.

**WebSocket log**: Ring buffer of last 30 entries. Each entry: `timestamp`, `direction` (in/out), `environmentId`, `messageType`, `bytes`, `success` (for decode failures).

Hook points:
- Outgoing: `EnvironmentConnection.send(_:)` (single centralized send point)
- Incoming: top of `handleMessage(_:)` in `EnvironmentConnection+MessageHandler.swift` (catches type after decode, plus log decode failures before the guard)

Start/stop all samplers when toggle changes. Pause FPS + memory when backgrounded.

### 3. DebugOverlayView (UI)
`UI/DebugOverlayView.swift`

**Minimized**: Single-line `60fps | 42MB | 1.2MB` in a small capsule. Tap to expand.

**Expanded**: ~250pt card with sections:
- Performance: FPS (color-coded green/yellow/red relative to device max Hz), memory
- Storage: Conversations dir size + count, cache size
- Network: Scrollable list of recent WS messages showing direction arrow, type name, byte size, relative timestamp

Draggable via `DragGesture`, snaps to nearest edge. `ultraThinMaterial` background. Constrained to safe area. Minimized state uses `.allowsHitTesting(false)` except on the pill itself.

### 4. Integration
- `CloudeApp.swift`: overlay on top of `mainContent`, reads `@AppStorage` toggle
- `SettingsView.swift`: toggle in preferences section
- `EnvironmentConnection.swift`: log outgoing in `send(_:)`
- `EnvironmentConnection+MessageHandler.swift`: log incoming in `handleMessage(_:)`, including decode failures

## Files
- **New**: `Cloude/Services/DebugMetrics.swift`
- **New**: `Cloude/UI/DebugOverlayView.swift`
- **Edit**: `Cloude/UI/SettingsView.swift` (add toggle)
- **Edit**: `Cloude/App/CloudeApp.swift` (add overlay)
- **Edit**: `Cloude/Services/EnvironmentConnection.swift` (log outgoing)
- **Edit**: `Cloude/Services/EnvironmentConnection+MessageHandler.swift` (log incoming + decode failures)

## Scroll Performance Metrics (for reliable-scroll-to-bottom ticket)

The debug overlay is a dependency for validating scroll performance fixes. These metrics should be prioritized in the first implementation:

- **FPS during scroll+streaming**: The FPS counter already planned above. Key comparison: FPS while scrolling during active streaming vs scrolling when idle. Target: no measurable difference between the two.
- **View body evaluation count**: Add counters on `ChatMessageList.body` and `StreamingContentObserver.body` (the new isolated streaming view). Show evaluations/sec in the overlay. Before the scroll fix, both fire at ~60Hz during streaming. After, only `StreamingContentObserver` should fire at 60Hz while `ChatMessageList` stays near 0.
- **objectWillChange fire rate**: Count `ConnectionManager.objectWillChange` fires per second. Before fix: ~60/sec during streaming. After: ~0/sec (only on empty/non-empty text transitions).

These three numbers give a clear before/after signal for whether Phase 1 of the scroll ticket actually worked.
