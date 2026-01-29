# Cloude Feature Roadmap

Ideas for improving the mobile Claude Code experience.

---

## Next Up: Projects & Git

### Projects ✅ DONE
A project groups conversations with shared settings:
- [x] **Root directory**: Claude Code always starts from this folder
- [x] **Name**: Display name for the project
- [x] **All conversations inherit project settings**
- [x] **Folder picker**: Browse Mac filesystem to select project root

**UI Flow:** ✅
1. Projects tab shows list of projects (each is a folder on Mac)
2. Tap project → see conversations for that project
3. New conversation auto-inherits project's root directory
4. Can still have "Quick Chats" without a project (uses home dir)

### Git Integration (per Project) - Partial
When a project has a git repo, show a "Changes" tab:
- [x] **Changed files list**: files modified since last commit
- [x] **Diff view**: tap file to see unified diff (syntax highlighted)
- [x] **Branch indicator**: show current branch in project header
- [x] **Ahead/behind count**: show commits ahead/behind remote
- [ ] **Stage/unstage**: toggle files for commit
- [ ] **Quick commit**: commit message + push in one tap
- [ ] **Pull/push buttons**: sync with remote
- [ ] **Tabs UI**: [Chats] [Changes] [Files] per project

---

## High Priority

### Real-time Progress Indicators - Partial
- [x] Show tool calls as they happen (name + input)
- [ ] Show current file being edited with before/after preview
- [ ] Display git operations (commits, branches) with visual diff
- [ ] Progress bar for long-running tasks
- [ ] Estimated tokens/cost display per conversation

### Conversation Context - Partial
- [x] Display active project name in header
- [x] Working directory per project (all conversations inherit)
- [ ] Quick switch between recent working directories
- [ ] Pin conversations to specific projects

### Notification Improvements
- [x] Background completion notifications
- [ ] Configurable notification verbosity (all output / errors only / completion only)
- [ ] Show which tool just ran in notification
- [ ] Critical error notifications with sound
- [ ] Background task progress in Dynamic Island (iOS 16+)

### Quick Actions
- [ ] Predefined prompt templates ("fix this error", "explain this file", "write tests")
- [ ] Recent prompts history
- [ ] Prompt snippets/shortcuts
- [ ] Voice input for prompts

---

## Medium Priority

### File Operations
- Upload files from iPhone to Mac
- Quick file sharing (send photo/screenshot to Claude)
- Edit text files directly in app
- Create new files remotely
- Delete/rename files

### Git Integration (Extended)
- View recent commits with messages
- Branch switching from app
- PR creation shortcut (gh pr create)
- Stash management
- Conflict resolution helper

### Session Management - Partial
- [x] Resume conversations with Claude Code session IDs
- [x] Conversation history persisted locally
- [ ] Export conversation to markdown
- [ ] Share conversation snippet
- [ ] Search across all conversations
- [ ] Conversation tags/categories

### Enhanced Tool Call Display - Partial
- [x] Show tool calls inline (name + input preview)
- [x] Expandable tool call rows (tap to see full input)
- [x] Tool-specific icons (terminal, doc, pencil, etc.)
- [ ] Full input/output display
- [ ] Syntax highlighted code in tool calls
- [ ] Collapsible tool call groups
- [ ] Filter view (show only edits, only reads, etc.)

---

## Quality of Life

### Offline Support
- Queue prompts when disconnected
- Cache recent file browser state
- View conversation history offline
- Auto-send queued prompts on reconnect

### Keyboard & Input
- External keyboard shortcuts
- Hardware keyboard support for iPad
- Swipe gestures (swipe to abort, swipe to resend)
- Haptic feedback on completion

### Widgets & Shortcuts
- Home screen widget showing agent status
- Lock screen widget for quick prompts
- Siri Shortcuts integration ("Hey Siri, ask Claude to...")
- Control Center toggle

### Multi-Mac Support
- Connect to multiple Mac agents
- Quick switch between machines
- Different auth tokens per machine
- Machine-specific conversation history

---

## Advanced Features

### Code Review Mode
- Side-by-side diff view for edits
- Approve/reject individual changes
- Batch approve all changes
- Undo last edit remotely

### Cost & Usage Tracking - Partial
- [x] Cost display per run (runStats message)
- [ ] Token usage per conversation
- [ ] Daily/weekly/monthly cost estimates
- [ ] Budget alerts
- [ ] Usage graphs over time

### Collaboration
- Share read-only conversation link
- Multiple iOS clients connected simultaneously
- Shared conversation history

### Watch App
- Glanceable status (idle/running)
- Quick abort from wrist
- Completion notifications
- Voice prompt input

---

## Technical Improvements

### Performance
- Message pagination for long conversations
- Lazy loading of file browser
- Image thumbnail caching
- Reduce memory usage for large responses

### Reliability
- Automatic session recovery after crash
- Retry failed messages
- Connection quality indicator
- Background app refresh for status checks

### Security - Partial
- [x] Face ID/Touch ID to unlock app
- [x] Auto-lock when app goes to background
- [ ] Auto-lock after inactivity timeout
- [ ] Encrypted local storage
- [ ] Option for TLS (self-signed cert)

---

## Ideas to Explore

- **Smart Summaries**: Auto-generate conversation titles based on content
- **Context Awareness**: Suggest prompts based on current file/directory
- **Error Detection**: Highlight when Claude seems stuck or confused
- **Learning Mode**: Explain what each tool does for new users
- **Dark Mode Sync**: Match Mac system appearance
- **Handoff**: Start on iPhone, continue on Mac (and vice versa)
- [x] **Multiple Conversations**: Run parallel Claude sessions on different projects

---

## Recently Completed

- [x] **Split chat view** - 1-4 panes for multiple simultaneous conversations, tap to activate
- [x] **Long press to copy** - context menu to copy message text with haptic feedback
- [x] **Face ID/Touch ID unlock** - biometric auth with settings toggle, auto-lock on background
- [x] **Projects system** - group conversations with shared root directory
- [x] **Folder picker** - browse Mac to select project folder
- [x] **Git integration** - status, diff view, branch indicator
- [x] **Tool call display** - inline with icons and expandable
- [x] **Markdown rendering** - headers, bold, code blocks, tables, blockquotes
- [x] **Collapsible sections** - tap headers to expand/collapse
- [x] **Session resumption** - continue conversations with Claude Code
- [x] **File browser** - browse Mac filesystem, preview files
- [x] **Background notifications** - notify when Claude completes
