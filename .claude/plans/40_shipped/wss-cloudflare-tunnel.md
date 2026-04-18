# WSS + Cloudflare Tunnel Support {lock.shield}
<!-- priority: 10 -->
<!-- tags: connection, security -->
<!-- build: 86 -->

> Auto-detect WSS for domain-name hosts and set up Cloudflare Tunnels for both environments.

## Test
- Connect to `cloude-medina.soli.blue` port 443 (should use wss://, connect successfully)
- Connect to `cloude-home.soli.blue` port 443 (should use wss://, connect to Mac agent)
- Connect to IP address on port 8765 (should still use ws://, work as before)

**Files:** `EnvironmentConnection.swift`
