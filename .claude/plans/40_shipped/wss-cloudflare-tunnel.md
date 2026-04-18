---
title: "WSS + Cloudflare Tunnel Support"
description: "Auto-detect WSS for domain-name hosts and set up Cloudflare Tunnels for both environments."
created_at: 2026-03-15
tags: ["connection", "security"]
icon: lock.shield
build: 86
---


# WSS + Cloudflare Tunnel Support {lock.shield}
## Test
- Connect to `cloude-medina.soli.blue` port 443 (should use wss://, connect successfully)
- Connect to `cloude-home.soli.blue` port 443 (should use wss://, connect to Mac agent)
- Connect to IP address on port 8765 (should still use ws://, work as before)

**Files:** `EnvironmentConnection.swift`
