# FEATURES.md

Source of truth for what Cloude can do and what's coming next.

---

## Current Features

### Core
- **Multi-window chat** - multiple conversations side by side (split/full layouts)
- **Heartbeat** - background session with configurable schedule (5 min to 1 day intervals)
- **Skills system** - extensible commands (/deploy, /icongen, /refactor, etc.)
- **Stop button** - cancel running Claude processes mid-execution
- **cloude CLI** - rename, symbol, memory commands sent from agent to iOS
- **Run stats** - duration and cost displayed on assistant messages

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
- [x] **Proactive execution** - cron-like behavior where Cloude can wake up and do things on a schedule (implemented via heartbeat intervals)
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
- [ ] **Tool call icons** - custom SF Symbol icons for each tool type (Read, Write, Bash, Grep, etc.) instead of text labels
- [x] **Tool grouping bug** - consecutive tool pills render correctly during streaming but stack vertically after reload (fixed: group by message ID in history sync)
- [ ] **Chained command parsing** - parse `&&` chains in Bash tool calls and display each command as a separate pill within the same group
- [ ] **Voice message resilience** - save recording to fixed temp file, show resend button on failure, delete on success
- [ ] **Compact input fields** - pill style with label on left, divider, input on right (more space efficient)
- [x] **Timestamp stability** - conversation list timestamps show minutes (not seconds)
- [x] **Feature tips in placeholder** - input bar placeholder rotates through feature tips
- [x] **Swipe to clear input** - swipe left on input bar to clear text

### Security
- [ ] **Tailscale requirement info** - show in iOS Settings and Mac Agent menu that Tailscale is required, with download link
- [ ] **Rate limiting** - basic rate limiting for auth attempts
- [ ] **Connection timeout** - disconnect unauthenticated connections after 30 seconds
