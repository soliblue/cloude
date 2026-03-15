# WSS + Cloudflare Tunnel Support
<!-- build: 86 -->

Auto-detect WSS for domain-name hosts. Cloudflare Tunnels set up for both environments.

## Test
- Connect to `cloude-medina.soli.blue` port 443 (should use wss://, connect successfully)
- Connect to `cloude-home.soli.blue` port 443 (should use wss://, connect to Mac agent)
- Connect to IP address on port 8765 (should still use ws://, work as before)

**Files:** `EnvironmentConnection.swift`
