# Android Debug Overlay {ant}
<!-- priority: 15 -->
<!-- tags: android, debug -->

> Debug metrics overlay showing connection stats, message counts, latency, and process tree.

## Desired Outcome
Toggle-able overlay showing WebSocket state, message throughput, latency, memory usage. Developer-only feature behind settings toggle. Also includes a process tree showing running Claude agent processes in a hierarchical view (parent-child relationships via ppid).

## Scope
- WebSocket connection state and reconnect count
- Message send/receive throughput
- Latency metrics
- Memory usage
- Process tree: hierarchical view of running agent processes with parent-child relationships, indentation, and chevron indicators

**Files (iOS reference):** DebugOverlayView.swift, DebugMetrics.swift, SettingsView+Sections.swift (process tree)
