# Cloude - Remote Claude

Control Claude Code from your iPhone. Your phone becomes a remote terminal for Claude Code running on any machine - Mac, Linux, or cloud.

```
┌──────────────┐              ┌──────────────┐
│   iPhone     │◄────────────►│  Mac / Linux │
│  (Cloude)    │  WebSocket   │   (relay)    │
└──────────────┘              └──────┬───────┘
                                     │
                                     ▼
                              ┌──────────────┐
                              │ Claude Code  │
                              │     CLI      │
                              └──────────────┘
```

The relay spawns Claude Code CLI processes and streams their output over WebSocket. The iOS app is a native chat UI. Use Cloudflare Tunnel for encrypted remote access (recommended), or connect directly on local WiFi.

## Quick Start

### Mac

```bash
open Cloude/Cloude.xcodeproj
```

1. Build **Cloude Agent** target (remove App Sandbox in Signing & Capabilities first)
2. Build **Cloude** target on your iPhone (add `App Transport Security Settings` > `Allow Arbitrary Loads` = YES in Info tab)
3. Copy auth token from the menu bar icon, enter it in the app with your Mac's IP and port 8765

### Linux

```bash
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo bash -
sudo apt-get install -y nodejs
npm install -g @anthropic-ai/claude-code && claude login
git clone https://github.com/soliblue/cloude.git
cd cloude/linux-relay && sudo bash install.sh
```

The install script creates a systemd service, generates an auth token, and starts the relay on port 8765. Get your token with `cat /opt/cloude-agent/data/auth-token`.

### Connect

On iPhone, enter your machine's hostname, port, and auth token.

### Remote Access

**Cloudflare Tunnel (recommended)** - free, no VPN app needed, automatic TLS:

```bash
# Install cloudflared
brew install cloudflare/cloudflare/cloudflared   # Mac
sudo apt install cloudflared                       # Linux

# Login and create tunnel
cloudflared login                                  # select your zone
cloudflared tunnel create cloude

# Configure (~/.cloudflared/config.yml)
cat > ~/.cloudflared/config.yml << EOF
tunnel: <TUNNEL_ID>
credentials-file: ~/.cloudflared/<TUNNEL_ID>.json

ingress:
  - hostname: cloude.yourdomain.com
    service: http://127.0.0.1:8765
  - service: http_status:404
EOF

# Create DNS route and run
cloudflared tunnel route dns cloude cloude.yourdomain.com
cloudflared service install  # runs on boot
```

In the iOS app, connect to `cloude.yourdomain.com` on port `443`. The app auto-detects domain names and uses `wss://` (encrypted WebSocket).

**Tailscale (alternative)** - works but drains iOS battery since it runs a VPN:

Install [Tailscale](https://tailscale.com) on both devices, then connect using the Tailscale IP on port `8765`.

## Features

### Multi-Environment

Talk to Claude on your personal laptop, your work machine, and a cloud server - all at the same time, from one app. Each environment gets its own file browser, terminal, and git view. Switch between them with a swipe.

| Feature | Description |
|---------|-------------|
| Mac relay | Native macOS menu bar app |
| Linux relay | Node.js service, one-line install, runs as systemd |
| Multiple connections | Connect to several machines at once, each in its own window |
| Per-environment tabs | Every environment has its own files, git, and terminal |

### Chat

Full Claude Code experience on your phone. Everything the CLI can do, you can do from the app.

| Feature | Description |
|---------|-------------|
| Real-time streaming | Responses stream in as Claude thinks |
| Tool call pills | Colored pills for every tool (Read, Edit, Bash, Grep, etc.) with expandable detail sheets |
| Rich markdown | Syntax-highlighted code, tables, collapsible headers, clickable file path pills |
| Multi-model | Switch between Opus, Sonnet, and Haiku per message |
| Voice input | Hold to record, transcribed with Whisper |
| Images and files | Attach photos, screenshots, or files to any message |
| Fork conversations | Branch off from any point to explore a different direction |
| Session resume | Pick up where you left off, even after closing the app |
| Run stats | Duration, cost, and model shown for every response |
| Slash commands | Trigger skills and shortcuts from the input bar |

### Windows

Run multiple conversations at the same time. Each one lives in its own window with its own tabs.

| Feature | Description |
|---------|-------------|
| Window switcher | Bottom dots to flip between conversations, plus button to create new ones |
| Auto-naming | A background Sonnet agent watches your conversation and picks a name and icon |
| Split / full layout | Stack two windows vertically or go full screen |
| 4 tabs per window | Chat, Files, Git, and Terminal |

### Files & Git

Browse and manage files on any connected machine, right from the app.

| Feature | Description |
|---------|-------------|
| File browser | Navigate directories with tap-to-open navigation |
| Rich previews | Code with syntax highlighting, CSV as scrollable tables, JSON as collapsible trees, images inline |
| Path pills | File paths in chat render as tappable pills that open the file |
| Git status | Branch, changed files, ahead/behind counts |
| Git diff | Per-file diffs with colored additions and deletions |
| Git commit | Stage files and commit without leaving the app |
| File search | Find files across the project |

### Agent Teams

Spawn multiple Claude agents that work together on the same project.

| Feature | Description |
|---------|-------------|
| Team orbs | Floating circles on the right edge showing each teammate's status |
| Speech bubbles | See what each agent is saying in real time |
| Team dashboard | Overview of all teammates with status and last message |
| Teammate detail | Drill into a specific agent's activity |

### Automation

Claude can work on its own and reach back to you through your phone.

| Feature | Description |
|---------|-------------|
| Heartbeat | Claude runs autonomously at a set interval - checking tasks, updating memory, doing housekeeping |
| Scheduled tasks | Recurring (cron) or one-time tasks, each in its own conversation that builds context over runs |
| Push notifications | Claude sends you a notification any time |
| Text-to-speech | Claude speaks out loud on your phone |
| Clipboard | Claude copies text to your clipboard |
| URL opening | Claude opens links on your phone |
| Screenshots | Claude captures your screen and sees it |
| Questions | Claude asks multiple-choice questions with tappable buttons |
| Haptics | Claude triggers haptic feedback on your phone |

### Memory & Plans

Persistent context that carries across conversations and sessions.

| Feature | Description |
|---------|-------------|
| Memory system | Two files: CLAUDE.md (project-level) and CLAUDE.local.md (personal). Claude reads and writes to them every session |
| Memories sheet | Browse and edit memory sections from the app |
| Plans | Ticket-based tracking with stages: backlog, next, active, testing, done |
| Plans sheet | Card view of all plans organized by stage |

### Interactive Widgets

Claude can render rich interactive components directly in chat.

| Category | Widgets |
|----------|---------|
| Data visualization | Bar charts, line charts, scatter plots, pie charts, function plots |
| Learning | Quizzes, flashcards, fill-in-the-blank, type-answer |
| Exploration | Timelines, trees, step-by-step reveals, image carousels |
| Activities | Matching, ordering, word scrambles, sentence builders, highlighting |
| Design | Color palettes, categorization, error correction |

### iOS Native

Built for iPhone, not a web wrapper.

| Feature | Description |
|---------|-------------|
| Live Activity | Lock screen widget showing run status, progress, and cost |
| Biometric lock | Face ID / Touch ID to protect your conversations |
| Swipe to delete | Swipe queued messages to cancel them |
| Cost banners | Warning when a conversation gets expensive |
| Adaptive UI | Layouts adjust to screen size and orientation |

## Architecture

**Mac relay** - native macOS menu bar app, WebSocket on port 8765, spawns Claude Code processes, streams output, serves files

**Linux relay** - Node.js, same WebSocket protocol, runs as a systemd service, single dependency (ws)

**iOS app** - WebSocket client, chat UI with streaming markdown, file browser, git viewer

## Requirements

- macOS 14+ or Linux (Ubuntu 22.04+)
- iOS 17+
- [Claude Code CLI](https://claude.ai/claude-code) installed
- Cloudflare Tunnel (recommended) or Tailscale for remote access

## TestFlight Deployment

Push a version tag to trigger a TestFlight build via GitHub Actions:

```bash
git tag v1.0.0
git push origin v1.0.0
```

Or trigger manually from the Actions tab. Requires these repository secrets:
- `CERT_P12_BASE64` - base64-encoded distribution certificate
- `CERT_PASSWORD` - certificate password
- `APP_STORE_CONNECT_API_KEY_ID`
- `APP_STORE_CONNECT_API_ISSUER_ID`
- `APP_STORE_CONNECT_API_KEY_CONTENT`

## License

MIT
