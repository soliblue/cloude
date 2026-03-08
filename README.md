# Cloude

Control Claude Code from your iPhone. Mac and Linux.

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

The relay spawns Claude Code CLI processes and streams their output over WebSocket. The iOS app is a native chat UI. Use Tailscale for encrypted remote access, or connect directly on local WiFi.

## Quick Start (Mac)

### 1. Install Tailscale (both devices)

```bash
# Mac
brew install --cask tailscale

# iPhone - App Store
```

Sign in with the same account on both.

### 2. Open in Xcode

```bash
open Cloude/Cloude.xcodeproj
```

### 3. Build the relay

1. Select **Cloude Agent** target
2. Go to **Signing & Capabilities**
3. **Remove App Sandbox** (click X on it)
4. Build and run (Cmd+R)

### 4. Build the iOS app

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

Done.

## Quick Start (Linux)

### 1. Install Node.js and Claude Code

```bash
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo bash -
sudo apt-get install -y nodejs
npm install -g @anthropic-ai/claude-code
claude login
```

### 2. Install the relay

```bash
git clone https://github.com/soliblue/cloude.git
cd cloude/linux-relay
sudo bash install.sh
```

This creates a systemd service, generates an auth token, and starts the relay on port 8765.

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

**Mac relay** - native macOS menu bar app, WebSocket on port 8765, spawns Claude Code processes, streams output, serves files

**Linux relay** - Node.js, same WebSocket protocol, runs as a systemd service, single dependency (ws)

**iOS app** - WebSocket client, chat UI with streaming markdown, file browser, git viewer

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
