# FEATURES.md

Source of truth for what Cloude can do and what's coming next.

---

## Implemented

### Core
- Multi-window chat (split/full layouts)
- Heartbeat (background session, 5 min to 1 day intervals)
- Skills system (/deploy, /icongen, /refactor, etc.)
- Stop button (cancel running processes)
- cloude CLI (rename, symbol, memory, delete, notify, clipboard, open, haptic, speak, switch, ask, screenshot)
- Run stats (duration and cost on messages)
- Proactive execution (heartbeat intervals)

### iOS App
- Interactive questions (`cloude ask` - multiple choice with tappable options)
- File browser with syntax-highlighted previews
- Git UI (uncommitted changes, diffs)
- Voice input (Whisper transcription)
- Live Activities (Lock Screen tracking)
- Text-to-speech (`cloude speak`)
- Screenshot capture (`cloude screenshot` - captures app view, sends as image to conversation)
- Screen awake during recording
- Voice message resilience (pending_audio.wav, resend banner)
- Swipe to clear input
- Feature tips in placeholder
- Timestamp stability (minutes not seconds)
- Heartbeat switcher icon (always accent)
- Heartbeat header cleanup
- Better /compact feedback (Live Activity shows "Compacting")

### Memory
- CLAUDE.md (project instructions)
- CLAUDE.local.md (personal memories)
- Memory commands (`cloude memory local/project`)
- Structured memory UI (collapsible sections, item counts)
- Nested memory hierarchy (### and #### subsections)

### Tool Display
- Tool call icons (SF Symbols per type, color coding)
- Tool detail popover (tap for full input, file paths)
- Nested tool hierarchy (expandable parent/children)
- Chained command parsing (`&&` chains as linked pills)
- Tool grouping fix (group by message ID)

### Security
- Tailscale requirement info (in Settings)
- Rate limiting (3 attempts in 5 min = lockout)

---

## Roadmap

### Big Vision
- [ ] Cross-project awareness - understanding how different repos relate
- [ ] 3-layer memory - context window → embeddings → CLAUDE.local.md
- [ ] External presence - email, marketplaces, communities

### Memory
- [x] Memory limits - 50K char limit with progress bar in Memories UI

### Tool Display
- [ ] Real-time tool updates - streaming progress in pills
- [ ] Tool output preview - inline expandable results

### iOS App
- [ ] Text-to-speech Phase 2 - Piper TTS for better quality
- [ ] Background audio - recording continues when locked
- [ ] Activity dashboard - track Cloude's presence
- [ ] File editing - edit files, not just browse
- [ ] Conversation search - search across all conversations
- [ ] Message reactions - quick feedback without typing
- [ ] Conversation export - markdown/PDF
- [ ] Compact input fields - pill style layout

### Security
- [ ] Connection timeout - disconnect unauthenticated after 30s
