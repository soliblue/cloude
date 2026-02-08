# Connection Guardrails {shield.lefthalf.filled}

> Remaining security hardening for WebSocket server (rate limiting already done): timeout unauthenticated connections after 30s, enforce max frame size, reject oversized payloads, warn when connecting from non-Tailscale IP, client-side auto-reconnect backoff with last error in UI.

**Files:** `WebSocketServer.swift`, `ConnectionManager.swift`
