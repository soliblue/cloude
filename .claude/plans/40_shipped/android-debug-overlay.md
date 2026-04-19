---
title: "Android Debug Overlay"
description: "Debug metrics overlay showing connection stats, message counts, latency, and process tree."
created_at: 2026-04-05
tags: ["android", "debug"]
build: 125
icon: ant
---
# Android Debug Overlay


## Desired Outcome
Toggle-able overlay showing WebSocket state, message throughput, latency, memory usage. Developer-only feature behind settings toggle. Also includes a process tree showing running Claude agent processes in a hierarchical view (parent-child relationships via ppid).

## Scope
- WebSocket connection state and reconnect count
- Message send/receive throughput
- Latency metrics
- Memory usage
- Process tree: hierarchical view of running agent processes with parent-child relationships, indentation, and chevron indicators

**Files (iOS reference):** DebugOverlayView.swift, DebugMetrics.swift, SettingsView+Sections.swift (process tree)
