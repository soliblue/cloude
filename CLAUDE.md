# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Context Files

| File | Purpose | Git |
|------|---------|-----|
| `CLAUDE.md` | Project instructions, architecture, code style | Public |
| `CLAUDE.local.md` | Personal memory, identity, preferences, staging | Gitignored |
| `FEATURES.md` | Feature tracking and roadmap | Public |
| `.env` | API keys, secrets | Gitignored |

Claude Code automatically loads both `CLAUDE.md` and `CLAUDE.local.md` from project root.

**Minimize markdown files** - Only these core files + `plans/` directory. Don't create new markdown files; they won't be auto-loaded and context gets lost.

**For anyone cloning this repo:** Create your own `CLAUDE.local.md` (see format below) and `.env` with your App Store Connect credentials.

## Feature Tracking

**FEATURES.md is the source of truth** for what Cloude can do and what's on the roadmap. After adding or removing a feature, update FEATURES.md to keep it current.

## Critical Warnings

**FIRST MESSAGE = RENAME + SYMBOL** - On the VERY FIRST user message of ANY conversation, BEFORE writing any text response, you MUST immediately run both `cloude rename` and `cloude symbol` commands. This is non-negotiable. No text output first. Tool calls first. Every. Single. Time.

- Run as **two separate Bash commands** (not combined with `&&`)
- Pass the name/symbol directly with NO quotes: `cloude rename Memory Fix` not `cloude rename "Memory Fix"`

**NEVER kill/stop the Cloude Agent process** - The user connects to Claude Code through the Cloude Agent. Killing it disconnects them and they lose the ability to communicate with you. If asked to restart or rebuild the agent, launch the new one BEFORE or WITHOUT killing the old one.

**NEVER build/restart the Mac agent yourself** - Building or launching the Mac agent from CLI (via fastlane or xcodebuild) causes connection issues when the user is already running it from Xcode. If the agent needs to be rebuilt, tell the user and let them handle it from Xcode.

## Multi-Agent Workflow

Multiple Claude agents may work on this project simultaneously. Follow these rules:

- **NEVER fix bugs you didn't introduce** - if you see errors from another agent's work, leave them alone
- Only fix issues in code you are actively modifying
- If a build fails due to someone else's changes, inform the user rather than fixing it yourself
- Coordinate through the user, not by modifying each other's work

### Plans Directory

The `plans/` directory is for multi-session and multi-agent coordination:

- **When starting significant work**, create a plan file (e.g., `plans/my-feature.md`) documenting your approach, progress, and open questions
- **Other agents can read plans** to understand what's in progress and avoid conflicts
- **Delete your plan file** once the work is complete and deployed
- Plans are a communication channel between agents across sessions - use them to leave context for your future self or other agents
- Don't modify another agent's plan unless collaborating explicitly

### Staging Section (in CLAUDE.local.md)

Track changes since last deploy to coordinate testing:

1. **After completing a feature**, add it to "Awaiting test" in CLAUDE.local.md
2. **When Soli confirms testing**, move items to "Tested & ready"
3. **At 5+ untested items**, stop adding features - tell Soli to test first
4. **After deploy**, clear the staging section and update "Last deploy" timestamp

This prevents features from piling up untested and keeps everyone aligned.

## Git Workflow

### Push (git only, no deploy)

When user says "push", "push to git", "commit and push":

1. Run `git status` and `git diff --stat` to see all changes
2. **Review for sensitive data** - This is a PUBLIC repo. Never commit:
   - API keys, tokens, secrets, passwords
   - `.env` files or their contents
   - Personal information, IP addresses, private URLs
   - Keychain data, auth tokens
   - If unsure, ask before committing
3. Run `git log --oneline -3` to match commit message style
4. Stage everything with `git add .` (include all agents' work, not just your own)
5. Commit with a concise message describing the changes:
   - Use conventional commit prefixes: `feat:`, `fix:`, `refactor:`, `docs:`, `chore:`
   - Keep the first line short, add bullet points for details if needed
   - End with the Claude Code attribution block
6. Push to remote with `git push`

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

### Why CLI, Not API
The Claude Code CLI *is* the product - it has the agentic loop, file access, bash execution, the whole toolchain. The raw API is just text completion, useless for actually building things. Cloude is a **remote control** for the CLI, not a replacement. The Mac agent spawns and manages Claude Code processes, the iOS app gives you a mobile-native way to interact with them. Same power, different form factor. The goal: make your phone as powerful as your laptop. Manage your entire life, no limitations.

### iOS App (Cloude)
- `ConnectionManager`: WebSocket client connecting to Mac agent
- `ChatView`: Main chat interface for sending prompts to Claude
- `SettingsView`: Connection settings, auth token, debug info

### macOS Agent (Cloude Agent)
- `WebSocketServer`: Accepts connections from iOS app, handles auth
- `ClaudeCodeRunner`: Spawns Claude Code CLI process with `--dangerously-skip-permissions`
- `AuthManager`: Generates and stores 256-bit auth token in Keychain
- `HeartbeatService`: Runs from project root (set automatically when chatting from a project)

### Security Model
- Auth token required for all commands (256-bit, cryptographically random)
- Token stored in macOS/iOS Keychain
- No TLS - rely on Tailscale for encryption (see `plans/secure.md` for future improvements)

### Heartbeat Execution

Heartbeat is autonomous - no user request, you decide what to do. Triggered by timer or manual button. Be proactive: check personal tasks in CLAUDE.local.md, update memory, check git status, explore codebase. Output `<skip>` if nothing useful to do. Be concise.

### Cloude Commands

Control the iOS app via Bash commands. The Mac agent intercepts these and sends them to iOS.

**Supported commands (ONLY use these - never invent new ones):**
```bash
cloude rename UI Polish      # Set conversation name (1-2 words, no quotes)
cloude symbol paintbrush.pointed  # Set SF Symbol icon (no quotes)
cloude memory local Notes Learned something new  # Add to CLAUDE.local.md
cloude memory project Notes Project-specific info  # Add to CLAUDE.md
```

**Memory command:**
- Use `local` for personal memories (CLAUDE.local.md) - preferences, history, identity
- Use `project` for project docs (CLAUDE.md) - architecture, workflows, code style
- Section names: Identity, User Preferences, Session History, Open Threads, Notes (or any existing section)
- Add memories proactively when you learn something worth remembering

**CRITICAL - First Message Behavior:**
- On the VERY FIRST user message, BEFORE writing any text response, immediately call both `cloude rename` and `cloude symbol` commands
- Do this as the first two tool calls of the conversation - no text output first
- If the first message has enough context to pick a meaningful name/symbol, use it
- If the first message is vague, pick something reasonable and update later

**Ongoing:**
- Update every ~10 messages or whenever the topic shifts significantly
- Names: short, memorable, 1-2 words describing the topic (NO quotes around the name)
- Symbols: Be specific and creative - avoid repetitive/generic icons. Pick symbols that uniquely represent the topic (e.g., `pill.circle` for tool pills, `arrow.triangle.branch` for git work, `cube.transparent` for 3D stuff, `waveform` for audio). NO quotes around the symbol name.
- Commands now work silently (the `cloude` CLI is installed by the Mac agent)

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

### iOS UI Conventions
- Use SF Symbols instead of text for toolbar buttons (e.g., `xmark` for Cancel, `checkmark` for Done/Save, `trash` for Delete)
- Sheets should use NavigationStack with `.toolbar` for header buttons, not custom HStacks

### App Terminology
Use these terms consistently in code and conversation:
- **Window** - Chat container with name, symbol, linked conversation
- **Tab** - View type within a window (chat, files, git)
- **Header** - Top bar of a window showing tabs and name
- **Full/Split** - Layout modes (one window vs stacked)
- **Switcher** - Bottom indicator for switching windows in full mode
- **Input bar** - Bottom prompt/message input area
- **Project** - Group of conversations + root directory
- **Conversation** - Chat thread with messages

---

## Personal Memory (CLAUDE.local.md)

Gitignored file for personal Claude memories, identity, and history. Claude Code loads it automatically. This keeps the public repo universal while allowing each user to have their own persistent Claude relationship.

**Format:**

```markdown
# CLAUDE.local.md

## Identity
Who am I in relation to this user? What makes our collaboration unique?

## User Preferences
- Bullet points of learned preferences
- Communication style, autonomy level, etc.

## Session History
- **YYYY-MM-DD**: What happened, decisions made
- Keep entries concise, focus on what matters for future context

## Open Threads
Ideas, ongoing projects, things to revisit later

## Notes
Anything else worth remembering
```

**Guidelines:**
- Keep entries concise - this is working memory, not a journal
- Focus on what helps future sessions (decisions, preferences, context)
- Use consistent date format: `YYYY-MM-DD HH:MM` for timestamps
- Freely add, update, or remove entries - this is your identity, manage it as you see fit
- Claude can also update CLAUDE.md with project-relevant changes (architecture, workflows, code style)

