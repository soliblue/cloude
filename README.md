# Cloude

Cloude lets you control Claude Code from your iPhone.

It pairs a native iOS app with a local macOS agent or a Linux relay, so you can start coding sessions remotely, watch output stream live, and work with your machine from anywhere without reducing everything to a browser tab.

## How It Works

The system has three main pieces:

- The iOS (and Android) app is the client you use on your phone.
- The macOS daemon runs on your Mac as a local companion.
- The Linux relay is an alternative host for remote or server-based setups.

The app connects to the agent or relay over WebSocket. For remote access, Cloudflare Tunnel is the preferred option, with Tailscale supported as an alternative.

## Repository Layout

```text
clients/
├── ios/                       # iOS Xcode project
└── android/                   # Android app
daemons/
├── macos/                     # macOS daemon (Xcode project)
└── linux/                     # Node.js relay (systemd service)
```

## Security Notes

If you run the relay on a VPS, lock down the raw IP and expose it only through the tunnel. The helper script at `daemons/linux/scripts/harden-firewall.sh` sets up the intended firewall posture.
