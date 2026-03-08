# Cloude

Control Claude Code CLI from your iPhone. Works anywhere via Tailscale.

```
                                    ┌──────────────┐
                             ┌─────►│     Mac      │
┌──────────────┐         ┌───┴──────┴──┐           │ (Cloude Agent)
│   iPhone     │◄───────►│  Tailscale   │           └──────────────┘
│  (Cloude)    │   WS    │   (VPN)      │                  │
└──────────────┘         └───┬──────┬──┘                  ▼
                             │      │           ┌──────────────┐
                             │      └──────────►│ Claude Code  │
                             │                  │     CLI      │
                             │                  └──────────────┘
                             │
                             │      ┌──────────────┐
                             └─────►│    Linux     │
                                    │ (Node.js     │
                                    │  agent)      │
                                    └──────┬───────┘
                                           ▼
                                    ┌──────────────┐
                                    │ Claude Code  │
                                    │     CLI      │
                                    └──────────────┘
```

## Quick Start (Mac)

### 1. Install Tailscale (both devices)

```bash
# Mac
brew install --cask tailscale

# iPhone
# Download from App Store
```

Sign in with the same account on both.

### 2. Open in Xcode

```bash
open Cloude/Cloude.xcodeproj
```

### 3. Configure macOS Agent

1. Select **Cloude Agent** target
2. Go to **Signing & Capabilities**
3. **Remove App Sandbox** (click X on it)
4. Build and run (Cmd+R)

### 4. Configure iOS App

1. Select **Cloude** target
2. Go to **Info** tab
3. Add `App Transport Security Settings` > `Allow Arbitrary Loads` = YES
4. Build and run on your iPhone

### 5. Connect

1. Click the cloud icon in Mac menu bar > copy auth token
2. On iPhone, enter:
   - Server: your Mac's Tailscale IP (`tailscale ip -4`)
   - Port: 8765
   - Token: paste from step 1

Done. Chat with Claude from your phone.

## Quick Start (Linux)

### 1. Install Node.js and Claude Code

```bash
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo bash -
sudo apt-get install -y nodejs
npm install -g @anthropic-ai/claude-code
claude login
```

### 2. Install the agent

```bash
git clone https://github.com/ahmedsoliman/cloude.git
cd cloude/agent-linux
sudo bash install.sh
```

This installs a systemd service, generates an auth token, and starts the agent on port 8765.

### 3. Connect from iPhone

1. Get the auth token: `cat /opt/cloude-agent/data/auth-token`
2. On iPhone, enter:
   - Server: your server's Tailscale IP (or public IP)
   - Port: 8765
   - Token: paste from step 1

## Features

- Chat with Claude Code CLI remotely
- Real-time streaming output
- Browse files on your machine
- View images, code, and documents
- Markdown rendering with syntax highlighting
- Git integration (status, diff, commit)
- File search
- Live Activity on iOS lock screen
- Agent teams support

## Architecture

**macOS Agent** (menu bar app)
- WebSocket server on port 8765
- Spawns Claude Code CLI
- Streams output to clients
- Serves files for browsing

**Linux Agent** (Node.js)
- WebSocket server on port 8765
- Same protocol as macOS agent
- Runs as a systemd service
- Lightweight: single dependency (ws)

**iOS App**
- WebSocket client
- Chat interface with streaming markdown
- File browser and media preview
- Git changes viewer

## Requirements

- macOS 14+ or Linux (Ubuntu 22.04+)
- iOS 17+
- [Claude Code CLI](https://claude.ai/claude-code) installed
- Tailscale (recommended for secure remote access)

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
