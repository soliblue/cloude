# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Critical Warning

**NEVER kill/stop the Cloude Agent process** - The user connects to Claude Code through the Cloude Agent. Killing it disconnects them and they lose the ability to communicate with you. If asked to restart or rebuild the agent, launch the new one BEFORE or WITHOUT killing the old one.

## Multi-Agent Workflow

Multiple Claude agents may work on this project simultaneously. Follow these rules:

- **NEVER fix bugs you didn't introduce** - if you see errors from another agent's work, leave them alone
- Only fix issues in code you are actively modifying
- If a build fails due to someone else's changes, inform the user rather than fixing it yourself
- Coordinate through the user, not by modifying each other's work

## Git Workflow

### Push (git only, no deploy)

When user says "push", "push to git", "commit and push":

1. Run `git status` and `git diff --stat` to see all changes
2. Run `git log --oneline -3` to match commit message style
3. Stage everything with `git add .`
4. Commit with a concise message describing the changes:
   - Use conventional commit prefixes: `feat:`, `fix:`, `refactor:`, `docs:`, `chore:`
   - Keep the first line short, add bullet points for details if needed
   - End with the Claude Code attribution block
5. Push to remote with `git push`

### Deploy (push + TestFlight + Mac agent)

When user says "deploy", "deploy to testflight", or "push and deploy":

1. Follow all push steps above
2. Run `source .env && fastlane deploy` to:
   - Build and launch Mac agent locally
   - Build iOS app and upload to TestFlight

## Build and Run Commands

```bash
# Deploy everything (Mac agent + iOS to TestFlight)
source .env && fastlane deploy

# iOS to TestFlight only
source .env && fastlane ios beta_local

# Mac agent only (build + launch)
source .env && fastlane mac build_agent

# Mac agent release (notarized DMG for distribution)
source .env && fastlane mac release_agent

# Build iOS for connected iPhone (without TestFlight)
xcodebuild -project Cloude/Cloude.xcodeproj -scheme Cloude -destination 'platform=iOS,name=My iPhone' build

# Clean build
xcodebuild -project Cloude/Cloude.xcodeproj -scheme Cloude clean
```

Open `Cloude/Cloude.xcodeproj` in Xcode to run on device.

## Deployment Setup

### First-Time Setup Checklist

1. **Create App in App Store Connect**
   - Go to App Store Connect > My Apps > + > New App
   - Bundle ID: `soli.Cloude`
   - SKU: `cloude-ios`
   - Platform: iOS

2. **Register App ID in Developer Portal**
   - Go to Certificates, Identifiers & Profiles > Identifiers
   - Create identifier with bundle ID `soli.Cloude`
   - Enable capabilities: App Groups, Push Notifications, Siri, Time Sensitive Notifications, Associated Domains, iCloud (with CloudKit)

3. **Set up `.env` file** (gitignored)
   ```
   APP_STORE_CONNECT_API_KEY_ID=<key_id>
   APP_STORE_CONNECT_API_ISSUER_ID=<issuer_id>
   APP_STORE_CONNECT_API_KEY_CONTENT="-----BEGIN PRIVATE KEY-----
   <key_content>
   -----END PRIVATE KEY-----"
   ```
   API key from: App Store Connect > Users and Access > Keys

4. **App Icon Requirements**
   - Must NOT have alpha/transparency (App Store rejects it)
   - To remove alpha: `sips -s format jpeg AppIcon.png --out temp.jpg && sips -s format png temp.jpg --out AppIcon.png`

5. **Info.plist Settings**
   - `ITSAppUsesNonExemptEncryption = NO` - skips encryption compliance modal

### App Store Connect
- **iOS App Bundle ID**: `soli.Cloude`
- **Mac Agent Bundle ID**: `soli.Cloude-Agent`
- **Team ID**: `Q9U8224WWM`
- **SKU**: `cloude-ios`

### iOS App Capabilities
- App Groups (`group.soli.Cloude`)
- Push Notifications
- Siri
- Time Sensitive Notifications
- Associated Domains
- iCloud (with CloudKit)

### Fastlane Lanes
Located in `fastlane/Fastfile`.

**IMPORTANT**: Always prefix with `source .env &&` to load API credentials!

| Command | Description |
|---------|-------------|
| `source .env && fastlane deploy` | Build Mac agent + iOS to TestFlight |
| `source .env && fastlane ios beta_local` | iOS to TestFlight only |
| `source .env && fastlane mac build_agent` | Mac agent local dev build |
| `source .env && fastlane mac release_agent` | Mac agent notarized DMG |

### Mac Agent Distribution
The Mac agent cannot go on the Mac App Store (requires sandboxing which breaks CLI spawning). Instead, use `fastlane mac release_agent` to create a notarized DMG for direct distribution.

## Project Structure

```
Cloude/
├── Cloude/                    # iOS app (iPhone client)
│   ├── App/
│   │   └── CloudeApp.swift
│   ├── UI/
│   │   ├── ChatView.swift
│   │   ├── SettingsView.swift
│   │   ├── FileBrowserView.swift
│   │   ├── FilePreviewView.swift
│   │   └── MarkdownText.swift
│   ├── Models/
│   │   └── Messages.swift
│   └── Services/
│       └── ConnectionManager.swift
│
└── Cloude Agent/              # macOS menu bar app (server)
    ├── App/
    │   └── Cloude_AgentApp.swift
    ├── UI/
    │   └── StatusView.swift
    ├── Models/
    │   └── Messages.swift
    └── Services/
        ├── WebSocketServer.swift
        ├── ClaudeCodeRunner.swift
        ├── AuthManager.swift
        └── FileManager.swift
```

## Architecture

### iOS App (Cloude)
- `ConnectionManager`: WebSocket client connecting to Mac agent
- `ChatView`: Main chat interface for sending prompts to Claude
- `SettingsView`: Connection settings, auth token, debug info

### macOS Agent (Cloude Agent)
- `WebSocketServer`: Accepts connections from iOS app, handles auth
- `ClaudeCodeRunner`: Spawns Claude Code CLI process with `--dangerously-skip-permissions`
- `AuthManager`: Generates and stores 256-bit auth token in Keychain

### Security Model
- Auth token required for all commands (256-bit, cryptographically random)
- Token stored in macOS/iOS Keychain
- No TLS - rely on Tailscale for encryption (see `plans/secure.md` for future improvements)

## Code Style

### General
- **NEVER add comments to code** - no inline comments, no docstrings, no file header comments (except the file name/module line). Code should be self-explanatory through clear naming.
- Avoid single-use helpers and variables
- Struct-first design for models and services
- Keep views lean with small composable structs
- Use explicit imports (no wildcards)
- Favor happy path with `if let`/`guard let`; avoid defensive detours
- Let errors propagate unless explicit handling is requested

### UI/Logic Separation
- **UI files should NOT contain**: date calculations, string formatting logic, data filtering/sorting, validation rules
- **Logic files should NOT contain**: SwiftUI views, colors, fonts, layout code
- Services should be pure structs with static methods when possible

### Chat UX Guidelines
- Minimize message movement during streaming - users should not have to chase content
- Scroll to position content at the start of streaming, not during
- Loading indicators should disappear once actual content is available (avoid redundant UI)
