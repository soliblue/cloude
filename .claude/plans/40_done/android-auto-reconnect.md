# Android Auto-Reconnect {wifi.exclamationmark}
<!-- priority: 7 -->
<!-- tags: android, reliability -->

> Automatically reconnect WebSocket when connection drops, with exponential backoff and state recovery.

## Desired Outcome
When the WebSocket disconnects (network change, server restart, app backgrounded too long), automatically reconnect and re-authenticate. Show connection state in UI during reconnection. Recover interrupted sessions via `requestMissedResponse`.

**Files (iOS reference):** EnvironmentConnection+Networking.swift (reconnect, reconnectIfNeeded), ConnectionManager.swift (reconnectAll, beginBackgroundStreamingIfNeeded)
