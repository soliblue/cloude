# Connection Guardrails

Remaining security hardening for WebSocket server (rate limiting already done):
- Timeout unauthenticated connections after 30s
- Enforce max frame size, reject oversized payloads
- Warn when connecting from non-Tailscale IP
- Client-side auto-reconnect backoff with last error in UI

**Files:** `WebSocketServer.swift`, `ConnectionManager.swift`
