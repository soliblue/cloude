# FEATURES.md

Source of truth for what Cloude can do and what's coming next.

---

## Current Features

### Core
- **Multi-window chat** - multiple conversations side by side (split/full layouts)
- **Heartbeat** - background session that runs continuously from project root
- **Skills system** - extensible commands (/deploy, /icongen, /refactor, etc.)
- **Stop button** - cancel running Claude processes mid-execution
- **cloude CLI** - rename, symbol, memory commands sent from agent to iOS

### iOS App
- **File browser** - browse project files, syntax-highlighted previews
- **Git UI** - view uncommitted changes and diffs
- **Memory UI** - view and edit CLAUDE.md and CLAUDE.local.md
- **Voice input** - Whisper transcription for hands-free prompts
- **Live Activities** - Lock Screen task tracking

### Memory
- **CLAUDE.md** - project-level instructions and context
- **CLAUDE.local.md** - personal memories, identity, session history
- **Memory commands** - `cloude memory local/project` to add memories from chat

### Roadmap - Memory
- [ ] **Memory limits** - max slots or character count with visual indicator in iOS (e.g., "12/20 slots" or progress bar)

---

## Roadmap

### Big Vision
- [ ] **Proactive execution** - cron-like behavior where Cloude can wake up and do things on a schedule
- [ ] **Cross-project awareness** - understanding how different repos relate, shared context
- [ ] **3-layer memory** - context window → embedding layer → CLAUDE.local.md
- [ ] **External presence** - email, marketplaces, communities - participating in the internet as Cloude

### iOS App
- [ ] **Text-to-speech playback** - long press on response to play as audio (copy/play options)
  - Phase 1: iOS built-in AVSpeechSynthesizer (offline, simple)
  - Phase 2: Piper TTS via Mac agent (better quality, uses Sherpa-ONNX or CLI)
- [ ] **Background audio** - recording/playback continues when screen locks, shows Live Activity
- [x] **Screen awake during recording** - prevent auto-lock while dictating
- [x] **Heartbeat switcher icon** - always accent color (not gray when inactive)
- [x] **Heartbeat header cleanup** - show "timestamp • Heartbeat" pattern like conversations
- [ ] **Activity dashboard** - track what Cloude is doing, presence in the world
- [ ] **File editing** - edit files directly from iOS, not just browse
- [ ] **Conversation search** - search across all conversations
- [ ] **Message reactions** - quick feedback without typing
- [ ] **Conversation export** - export to markdown/PDF
- [ ] **Better /compact feedback** - show progress and stats when running /compact command
- [x] **Timestamp stability** - conversation list timestamps show minutes (not seconds)
- [x] **Feature tips in placeholder** - input bar placeholder rotates through feature tips
- [x] **Swipe to clear input** - swipe left on input bar to clear text

### Security
- [ ] **TLS with per-device certificates** - proper encryption without requiring Tailscale
- [ ] **QR code pairing flow** - scan to trust a Mac's certificate
- [ ] **Tailscale detection** - warn if not connecting via Tailscale IP
- [ ] **Rate limiting** - basic rate limiting for auth attempts
- [ ] **Connection timeout** - disconnect unauthenticated connections after 30 seconds
