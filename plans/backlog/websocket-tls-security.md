# WebSocket TLS Security

Without Tailscale, all WebSocket traffic (including auth token) is plaintext. Anyone on the same network can sniff it.

## Desired Outcome
TLS encryption for the WebSocket connection with a pairing flow (QR code with cert fingerprint) so it works without Tailscale. Tailscale detection and warning already done. Rate limiting already done.

**Files:** `WebSocketServer.swift`, `ConnectionManager.swift`, `AuthManager.swift`, `SettingsView.swift`
