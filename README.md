# Cloude

Control Claude Code CLI from your iPhone. Works anywhere via Tailscale.

```
┌──────────────┐         ┌──────────────┐         ┌──────────────┐
│   iPhone     │◄───────►│  Tailscale   │◄───────►│     Mac      │
│  (Cloude)    │   WS    │   (VPN)      │         │ (Cloude Agent│
└──────────────┘         └──────────────┘         └──────────────┘
                                                         │
                                                         ▼
                                                  ┌──────────────┐
                                                  │ Claude Code  │
                                                  │     CLI      │
                                                  └──────────────┘
```

## Quick Start

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
3. Add `App Transport Security Settings` → `Allow Arbitrary Loads` = YES
4. Build and run on your iPhone

### 5. Connect

1. Click the cloud icon in Mac menu bar → copy auth token
2. On iPhone, enter:
   - Server: your Mac's Tailscale IP (`tailscale ip -4`)
   - Port: 8765
   - Token: paste from step 1

Done. Chat with Claude from your phone.

## Features

- Chat with Claude Code CLI remotely
- Real-time streaming output
- Browse files on your Mac
- View images and videos
- Markdown rendering

## Architecture

**macOS Agent** (menu bar app)
- WebSocket server on port 8765
- Spawns Claude Code CLI
- Streams output to clients
- Serves files for browsing

**iOS App**
- WebSocket client
- Chat interface
- File browser
- Media preview

## Requirements

- macOS 14+
- iOS 17+
- [Claude Code CLI](https://claude.ai/claude-code) installed
- Tailscale (free)

## License

MIT
