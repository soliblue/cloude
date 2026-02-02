# Platform Hardening Plan

## Goals
- Reduce risk on non-Tailscale networks without blocking current workflow.
- Make connections more resilient and diagnosable.
- Add capability negotiation so iOS and agent can drift safely.

## Current Observations
- WebSocket is raw TCP, no TLS, no per-connection timeouts or rate limits.
- Auth is a static token in Keychain; no rotation or device trust model.
- No explicit keepalive or ping/pong from iOS; server only responds to pings.
- Protocol has no version/capability negotiation.

## Opportunities

### Quick Wins (low risk)
- Add unauthenticated connection timeout and close on idle.
- Add simple auth rate limiting per connection (fail count + time window).
- Add payload size limits in WebSocket frame parser.
- Warn when the client connects from a non-Tailscale IP.
- Add optional "local-only" bind mode for localhost + SSH tunnel.

### Medium Scope
- Add keepalive pings from agent with backoff + client pong handling.
- Track connection health (RTT, last ping) and surface in Settings.
- Add token rotation UI on macOS + iOS and invalidate old sessions.

### Larger Scope
- TLS with per-device certificates and QR pairing (builds on plans/secure.md).
- Capability negotiation on connect (client/app version, supported message types).

## Proposed Phases

### Phase 0 - Guardrails
1. Connection timeout for unauthenticated clients (e.g., 30s).
2. Rate limit auth attempts per connection and per IP.
3. Enforce max frame size and reject oversized payloads.
4. Add client-side auto-reconnect backoff and show last error in UI.

### Phase 1 - Connection Health
1. Implement ping/pong keepalive on agent and iOS.
2. Add connection health status (last ping, RTT, retries).
3. Telemetry-only logging for auth failures and disconnect reasons.

### Phase 2 - Trust Model
1. Token rotation flow + device trust list.
2. TLS + QR pairing (per-device certs), with fallback to Tailscale mode.
3. Capability negotiation and protocol versioning.

## Notes / Dependencies
- WebSocket server: `Cloude/Cloude Agent/Services/WebSocketServer.swift` and `WebSocketServer+HTTP.swift`.
- iOS client: `Cloude/Cloude/Services/ConnectionManager.swift`.
- Settings UI for warnings and trust list: `Cloude/Cloude/UI/SettingsView.swift`.
- TLS plan details live in `plans/secure.md`.
