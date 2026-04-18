# Cloude

Cloude lets you control Claude Code from your iPhone.

It pairs a native iOS app with a local macOS agent or a Linux relay, so you can start coding sessions remotely, watch output stream live, and work with your machine from anywhere without reducing everything to a browser tab.

## How It Works

The system has three main pieces:

- The iOS app is the client you use on your phone.
- The macOS agent runs on your Mac as a local companion.
- The Linux relay is an alternative host for remote or server-based setups.

The app connects to the agent or relay over WebSocket. For remote access, Cloudflare Tunnel is the preferred option, with Tailscale supported as an alternative.

## Repository Layout

```text
Cloude/
├── Cloude/                    # iOS app
├── Cloude Agent/              # macOS menu bar agent
├── CloudeShared/              # Shared Swift package
└── iOS/                       # iOS-specific assets
linux-relay/                   # Node.js relay
```

## Security Notes

If you run the relay on a VPS, lock down the raw IP and expose it only through the tunnel. The helper script at `linux-relay/scripts/harden-firewall.sh` sets up the intended firewall posture.
