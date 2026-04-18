---
title: "Android Auto-Reconnect"
description: "Automatically reconnect WebSocket when connection drops, with exponential backoff and state recovery."
created_at: 2026-03-28
tags: ["android", "reliability"]
icon: wifi.exclamationmark
build: 120
---
# Android Auto-Reconnect {wifi.exclamationmark}


## Desired Outcome
When the WebSocket disconnects (network change, server restart, app backgrounded too long), automatically reconnect and re-authenticate. Show connection state in UI during reconnection. Recover interrupted sessions via `requestMissedResponse`.

**Files (iOS reference):** EnvironmentConnection+Networking.swift (reconnect, reconnectIfNeeded), ConnectionManager.swift (reconnectAll, beginBackgroundStreamingIfNeeded)
