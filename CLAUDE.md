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

**NEVER USE AskUserQuestion TOOL** - The iOS app cannot handle interactive question prompts from the CLI. When you need to ask the user something, just ask in plain text in your response. The user will reply in the next message. Do not use the AskUserQuestion tool - it will break the conversation flow.

**FIRST MESSAGE = RENAME + SYMBOL** - On the VERY FIRST user message of ANY conversation, BEFORE writing any text response, you MUST immediately run both `cloude rename` and `cloude symbol` commands. This is non-negotiable. No text output first. Tool calls first. Every. Single. Time.

- Run as **two separate Bash commands** (not combined with `&&`)
- Pass the name/symbol directly with NO quotes: `cloude rename Memory Fix` not `cloude rename "Memory Fix"`

**Rebuilding the Mac agent** - You CAN rebuild the agent using `source .env && fastlane mac build_agent`. The build process will SIGKILL the old agent, wait 3s, and launch the new one. The WebSocket server has retry logic (up to 5 attempts) if the port is still in use. Deploying both agent + iOS together (`fastlane deploy`) is safe. **CRITICAL:** Always run this as the LAST thing in your response. Say everything important first, then trigger the build. The connection will drop briefly but the iOS app will reconnect automatically.

## Multi-Agent Workflow

**⚠️ CRITICAL: Multiple Claude agents work on this project simultaneously.**

- **NEVER touch another agent's code** - if you see errors, broken builds, or issues from another agent's work, **STOP and tell Soli**. Do not fix it yourself, even if it seems simple.
- **ASK before fixing build errors** - if a build fails and it's not clearly your code, ask Soli before touching it
- Only modify code you are actively working on for your current task
- Coordinate through Soli, not by modifying each other's work
- When in doubt, ask first

### Plans Directory

The `plans/` directory is the single source of truth for tracking work. Every change gets a ticket.

**Lifecycle**: `backlog/ → next/ → active/ → testing/ → done/`

**Rules:**
- **Every code change needs a plan ticket** — if a plan already exists, move it. If not, create one.
- After implementing a change, move/create the plan in `testing/`
- When Soli confirms it works, move to `done/`
- At **5+ items in testing/**, stop adding features — tell Soli to test first
- Other agents can read plans to understand what's in progress and avoid conflicts
- Only move your own plans (multi-agent coordination)
- Don't modify another agent's plan unless collaborating explicitly
- Plans are a communication channel between agents across sessions

**Ad-hoc requests** (no existing ticket): When Soli asks for a quick change that has no plan, create a small plan file directly in `testing/` after implementing it. This ensures nothing gets lost.

**The `testing/` folder replaces the CLAUDE.local.md staging section** — don't duplicate tracking in both places.

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
- **Path Links**: Full absolute paths starting with `/Users/` render as clickable file pills in tool results and inline text, opening file preview or folder browser

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

Heartbeat is autonomous - no user request, you decide what to do. Triggered by timer or manual button. Be proactive: check personal tasks in CLAUDE.local.md, update memory, check git status, explore codebase. Use `cloude skip` if nothing useful to do. Be concise.

### Cloude Commands

Control the iOS app via Bash commands. The Mac agent intercepts these and sends them to iOS.

**Supported commands (ONLY use these - never invent new ones):**
```bash
cloude rename UI Polish      # Set conversation name (1-2 words, no quotes)
cloude symbol paintbrush.pointed  # Set SF Symbol icon (no quotes)
cloude memory local Notes Learned something new  # Add to CLAUDE.local.md
cloude memory project Notes Project-specific info  # Add to CLAUDE.md
cloude skip                  # Signal heartbeat skip (nothing useful to do)
cloude delete                # Delete the current conversation
cloude notify Task complete! # Send a push notification to iOS
cloude clipboard <text>      # Copy text to iOS clipboard
cloude open https://...      # Open a URL on iOS
cloude haptic <style>        # Trigger haptic feedback (light/medium/heavy/rigid/soft)
cloude speak Hello world     # Text-to-speech on iOS
cloude switch <conv-id>      # Switch to a different conversation by UUID
cloude ask --q "Question?" --options "A,B,C"  # Ask user a multiple-choice question
```

**Asking Questions (`cloude ask`):**
Use for multiple-choice questions — renders as tappable option buttons in iOS. User's answers come back as the next message (e.g., "Color? Blue\nSize? M, L"). For open-ended questions, just ask in plain text instead.

Formats:
```bash
# Simple (single question, single-select)
cloude ask --q "What color?" --options "Red,Blue,Green"

# With descriptions (colon separates label:description)
cloude ask --q "Which approach?" --options "A:Fast but complex,B:Simple but slow"

# Multi-select (user can pick multiple)
cloude ask --q "Which languages?" --options "Swift,Python,Rust" --multi

# Multiple questions (JSON array) - PREFERRED for 2+ questions
cloude ask --questions '[{"q":"Coffee or tea?","options":["Coffee","Tea"]},{"q":"Languages?","options":["Swift","Python","Rust"],"multi":true}]'
```

JSON format for `--questions`:
- `q`: question text (required)
- `options`: array of strings (required)
- `multi`: boolean for multi-select (optional, default false)

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
- **File size limit**: For files >150 lines, use `ParentView+Feature.swift` extensions to break down complexity (e.g., `SettingsView+Cards.swift`, `ChatView+Components.swift`)
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
- When placing multiple buttons in a toolbar (e.g., trailing), add a `Divider().frame(height: 20)` between them for visual separation

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

- **2026-02-01**: For Read/Write/Edit tool calls, the input is already the file path string (extracted by Mac agent), not JSON. Use it directly.
- **2026-02-01**: Tool call input for Read/Write/Edit is the raw file path string not JSON
- **2026-02-01**: To show a clickable file pill in responses, reference the full absolute path starting with /Users/ - it renders as icon + filename
