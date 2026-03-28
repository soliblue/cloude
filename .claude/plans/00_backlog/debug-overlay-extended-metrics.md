# Debug Overlay: Extended Metrics {gauge.with.dots.needle.33percent}
<!-- priority: 6 -->
<!-- tags: ui, agent -->

> Extend the debug overlay with more device, connection, and rendering diagnostics.

The debug overlay currently shows FPS and OWC/sec. Add more metrics incrementally as needed.

## Desired Outcome
A richer debug panel that helps identify memory leaks, storage bloat, and WebSocket issues without Xcode.

**Candidates (add as needed):**
- **RAM**: `task_vm_info.phys_footprint` via mach API, poll every 2s off main thread
- **Storage**: `Documents/conversations/` and `Documents/cache/` dir sizes + file count, poll every 10s off main
- **WebSocket log**: Ring buffer of last 30 messages (direction, type, bytes, timestamp, decode success)
- **View body eval count**: Counters on hot views to confirm isolation fixes work

**Files:** `DebugMetrics.swift`, `DebugOverlayView.swift`, `EnvironmentConnection.swift`, `EnvironmentConnection+MessageHandler.swift`
