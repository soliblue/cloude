# iOS Experience Plan

## Goals
- Make mobile usage faster, more discoverable, and more resilient when connectivity is spotty.
- Reduce UI friction for frequent actions (run, resend, browse files, manage windows).
- Surface the most valuable info (tool calls, cost/time, active tasks) at a glance.

## Current Observations
- Tool call details assume JSON input, but agent sends plain strings for many tools.
- File browsing is read-only and uses single callbacks in ConnectionManager.
- Conversations are stored in UserDefaults; large histories may eventually feel heavy.
- Search, export, and pinning are not present.

## Opportunities

### Chat and Window UX
- Global conversation search and filter by project.
- Pin/favorite conversations and windows.
- Quick actions in header: retry last run, fork session, run /compact.
- Provide a small run summary row (duration, cost) that is tappable for details.

### Tool Call and Output Clarity
- Fix tool call detail parsing for string inputs (Bash, Read, Write, Edit).
- Add a compact tool call timeline (first/last tool, count, duration).
- Make tool call rows expand with syntax-highlighted input.

### File Workflows
- Add basic file editing with preview + diff (read, edit, confirm).
- Support share sheet import (send a local file to agent for analysis).
- Add "copy path" and "open in Files" actions.

### Voice and Audio
- Improve dictation UX with background audio and lock screen controls.
- Optional TTS playback on assistant messages.

### Offline and Reliability
- Queue outgoing prompts while offline and send when connected.
- Retry failed requests with a small indicator badge.

## Proposed Phases

### Phase 0 - Clarity and Fixes
1. Update tool call detail parsing to support plain string inputs.
2. Surface run stats in message UI with a small, consistent layout.
3. Add a "retry last run" action in the header.

### Phase 1 - Search and Navigation
1. Conversation search across all projects.
2. Pin/favorite conversations and windows.
3. Quick switcher improvements (jump by recent activity).

### Phase 2 - File Editing
1. Read file -> edit -> preview diff -> confirm write.
2. Add basic conflict detection (file changed since read).
3. Optional per-project edit permissions.

### Phase 3 - Audio and Media
1. Built-in TTS playback for assistant responses.
2. Background dictation with Live Activity.

## Notes / Dependencies
- Tool call parsing: `Cloude/Cloude/Services/ConnectionManager+API.swift`.
- File browser: `Cloude/Cloude/UI/FileBrowserView.swift` and `FilePreviewView.swift`.
- Run stats: `Cloude/Cloude/UI/ChatView+MessageBubble.swift`.
- Settings and pinning: `Cloude/Cloude/Models/WindowManager.swift` and `ProjectStore.swift`.
