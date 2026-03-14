# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Context Files

| File | Purpose | Git |
|------|---------|-----|
| `CLAUDE.md` | Project instructions, architecture, code style | Public |
| `CLAUDE.local.md` | Personal memory, identity, preferences | Gitignored |
| `.claude/plans/` | Feature tracking, roadmap, work coordination | Public |
| `.claude/skills/` | Skill implementations (canonical location) | Public |
| `.env` | API keys, secrets | Gitignored |

Claude Code automatically loads both `CLAUDE.md` and `CLAUDE.local.md` from project root.

**Minimize markdown files** - Only these core files + `.claude/plans/` directory. Don't create new markdown files; they won't be auto-loaded and context gets lost.

**For anyone cloning this repo:** Create your own `CLAUDE.local.md` (see format below) and `.env` with your App Store Connect credentials.

## Critical Warnings

**NEVER USE AskUserQuestion TOOL** - The iOS app cannot handle interactive question prompts from the CLI. When you need to ask the user something, just ask in plain text in your response. The user will reply in the next message. Do not use the AskUserQuestion tool - it will break the conversation flow.

**NAMING IS AUTOMATIC** - A background Sonnet agent automatically generates a conversation name + SF Symbol on the 1st and 2nd user messages, then every 5 assistant messages. You do NOT need to call `mcp__ios__rename` or `mcp__ios__symbol` on the first few messages. The name appears in the header within a few seconds. You can still rename later if the topic shifts significantly (~10+ messages in).

**NEVER run `fastlane mac build_agent` directly** — it kills the agent hosting your session. Use the `/deploy` skill instead.

## Multi-Agent Workflow

**⚠️ CRITICAL: Multiple Claude agents work on this project simultaneously.**

- **NEVER touch another agent's code** - if you see errors, broken builds, or issues from another agent's work, **STOP and tell the user**. Do not fix it yourself, even if it seems simple.
- **ASK before fixing build errors** - if a build fails and it's not clearly your code, ask the user before touching it
- Only modify code you are actively working on for your current task
- Coordinate through the user, not by modifying each other's work
- When in doubt, ask first

### Plans Directory

Every code change needs a plan ticket in `.claude/plans/`. Lifecycle: `00_backlog/ → 10_next/ → 20_active/ → 30_testing/ → 40_done/`. Use the `/plan` skill for full rules. Key rules: create ticket before coding, only move your own plans, at 5+ items in `30_testing/` stop and test first.

## Project Structure

```
Cloude/
├── Cloude/                    # iOS app (iPhone client)
│   ├── App/
│   │   └── CloudeApp.swift
│   ├── UI/                    # (split into +Components files)
│   ├── Models/
│   └── Services/
│       └── ConnectionManager.swift
│
├── Cloude Agent/              # macOS menu bar app (server)
│   ├── App/
│   │   └── Cloude_AgentApp.swift
│   ├── UI/
│   │   └── StatusView.swift
│   └── Services/
│       ├── WebSocketServer.swift
│       ├── ClaudeCodeRunner.swift
│       ├── AuthManager.swift
│       └── HeartbeatService.swift
│
├── CloudeShared/              # Shared Swift package
│   └── Sources/CloudeShared/
│       └── Messages/          # ClientMessage, ServerMessage contracts
│
└── CloudeLiveActivity/        # Live Activity extension
    └── CloudeLiveActivity.swift
```

## Architecture

### Why CLI, Not API
The Claude Code CLI *is* the product - it has the agentic loop, file access, bash execution, the whole toolchain. The raw API is just text completion, useless for actually building things. Cloude is a **remote control** for the CLI, not a replacement. The Mac agent spawns and manages Claude Code processes, the iOS app gives you a mobile-native way to interact with them. Same power, different form factor. The goal: make your phone as powerful as your laptop. Manage your entire life, no limitations.

### iOS App (Cloude)
- `ConnectionManager`: WebSocket client connecting to Mac agent
- UI split into component files (see UI Component Map below for details)
- **Path Links**: Full absolute paths starting with `/Users/` render as clickable file pills in tool results and inline text, opening file preview or folder browser
- **Question UI**: `ConversationView+Question` renders multiple-choice questions (to be redesigned as a widget)

### macOS Agent (Cloude Agent)
- `WebSocketServer`: Accepts connections from iOS app, handles auth
- `ClaudeCodeRunner`: Spawns Claude Code CLI process with `--dangerously-skip-permissions`
- `AuthManager`: Generates and stores 256-bit auth token in Keychain
- `HeartbeatService`: Runs from project root (set automatically when chatting from a project)
- `MemoryService`: Writes to CLAUDE.md and CLAUDE.local.md

### CloudeShared Package (Swift PM)
- **Message Contracts**: `ClientMessage` and `ServerMessage` define WebSocket protocol
- **Shared Models**: `UsageStats`, `ToolCall`, `TeammateInfo`, `PlanStage` used by both iOS and Mac agent
- Location: `Cloude/CloudeShared/` - Swift Package Manager module

### Live Activity Extension
- **CloudeLiveActivityExtension**: iOS widget showing run status, progress, cost
- Updates via ActivityKit when Claude Code is running
- Location: `Cloude/CloudeLiveActivity/CloudeLiveActivity.swift`

### Security Model
- Auth token required for all commands (256-bit, cryptographically random)
- Token stored in macOS/iOS Keychain
- No TLS - works over local WiFi (both devices on same network) but we recommend Tailscale for encrypted remote access

### Dev Notes
- Heartbeat session ID: use `--resume` for existing sessions, not `--session-id` (creates new)
- Tool call input for Read/Write/Edit is the raw file path string not JSON
- Agent teams: CLI returns plain text for Task results, TeamCreate/Delete returns JSON. Read `~/.claude/teams/{name}/config.json` for color/model/agentType.
- Sora credits: Reset on rolling ~4.5hr timer, not midnight

### Heartbeat Execution

Heartbeat is autonomous - no user request, you decide what to do. Triggered by timer or manual button. Be proactive: check personal tasks in CLAUDE.local.md, update memory, check git status, explore codebase. Use `mcp__ios__skip` if nothing useful to do. Be concise.

### iOS Control (MCP)

Control the iOS app via `mcp__ios__*` tool calls. The Mac agent intercepts these from the Claude Code output stream and routes them to the iOS app. Available tools: `rename`, `symbol`, `notify`, `clipboard`, `open`, `haptic`, `switch`, `delete`, `skip`, `screenshot`. Each tool is self-documenting - check the tool descriptions for usage details.

## Code Style

### App Colors
- **Accent color is orange** (rgb 0.8/0.447/0.341) - set in `AccentColor.colorset`, NOT the iOS default blue. `Color.accentColor` everywhere in the app resolves to this warm orange/coral.
- Background colors come from the theme system (`AppTheme` in `Theme.swift`) - ocean dark is the default with deep navy tones
- The `Colors.swift` file maps theme palette values to `Color.ocean*` static properties

### Simplicity-First
- **Less is more** - always prefer the simplest solution
- **Code should be beautiful** - treat it like art
- **The simpler the code, the fewer bugs**

### General
- **NEVER add comments to code** - no inline comments, no docstrings, no file header comments (except the file name/module line). Code should be self-explanatory through clear naming.
- **File size limit**: For files >150 lines, use `ParentView+Feature.swift` extensions to break down complexity (e.g., `SettingsView+Sections.swift`, `MessageBubble+Components.swift`)
- Struct-first design for models and services
- Keep views lean with small composable structs
- Use explicit imports (no wildcards)
- Let errors propagate unless explicit handling is requested
- **Never use em dashes** (—) anywhere - not in code, comments, commit messages, chat, or generated text. Use hyphens (-) or rewrite the sentence instead.

### No-Try-Catch
- **Never add do-catch blocks** unless explicitly requested
- **Let errors propagate naturally**
- **Fail fast and loud**

### No-Single-Use-Variables
- If a variable is only read once, return or use the expression directly

```swift
// Bad
let result = calculateSomething()
return result

// Good
return calculateSomething()
```

### No-Single-Use-Functions
- **If a function is only called once, inline it** - single-use functions fragment the code and make it harder to read
- **Always align before creating new functions** - propose function extraction and get confirmation first
- Only extract functions when they are reused in multiple places
- Reading code top-to-bottom is easier than jumping between functions

### Happy-Path (CRITICAL)
- **ALWAYS check for success, NEVER check for failure**
- **Condition should be positive** - use `if let` not `guard let` with early return for the common case
- **Less code is better** - avoid if-else with error handling in the if branch
- **NEVER use guard clauses with negation** - `guard !x else { return }` is an anti-pattern here

```swift
// Bad (guard clause anti-pattern)
guard let subject = args.subject else { return }
guard directory.exists() else { return }
guard playlist != nil else { return }

// Good (happy path)
if let subject = args.subject {
    if directory.exists() {
        process(subject)
    }
}
```

The key insight: structure your code so the condition reads as "if this good thing is true, do the work" rather than "if this bad thing is true, bail out".

### Prefer-Ternary
- **Use ternary operator for simple conditional assignments**

```swift
// Bad
let role: String
if user.isAdmin {
    role = "admin"
} else {
    role = "user"
}

// Good
let role = user.isAdmin ? "admin" : "user"
```

### UI/Logic Separation
- **UI files should NOT contain**: date calculations, string formatting logic, data filtering/sorting, validation rules
- **Logic files should NOT contain**: SwiftUI views, colors, fonts, layout code
- Services should be pure structs with static methods when possible

### Chat UX Guidelines
- Minimize message movement during streaming - users should not have to chase content
- Scroll to position content at the start of streaming, not during
- Loading indicators should disappear once actual content is available (avoid redundant UI)
- Never use brace notation like {1-6} when referencing files in chat - each file must be a full absolute path to render as a tappable pill

### Widgets vs Extended Markdown

The iOS app has two systems for rich content: **markdown extensions** (inline, parsed from text) and **MCP widgets** (structured tool calls via `mcp__widgets__*`).

**Markdown extensions** (what the parser already handles):
- **File paths**: Bare `/Users/...` paths render as tappable pills with file-type icons
- **Code blocks**: Syntax highlighting, line numbers, copy button, text wrap toggle
- **Tables**: Pipe-delimited `| col | col |` with header row highlighting
- **Collapsible headers**: `## Header` sections can expand/collapse
- **Checkboxes**: `- [ ]` and `- [x]` render as visual checkboxes
- **Blockquotes**: `> text` with left border

**When to use markdown**: Text-heavy explanations, code snippets, file references, simple tables, lists. Anything that flows naturally in a sentence.

**When to use widgets** (`mcp__widgets__*` tool calls):
- **Interactive content**: Sliders, tappable elements, flip cards, drag-to-order
- **Visual/spatial data**: Charts, trees, timelines, color palettes
- **Structured data better shown visually**: Hierarchies (tree), sequences (timeline), comparisons (bar chart), proportions (pie chart)

**Rule of thumb**: If markdown can express it clearly, use markdown. If the data has structure that benefits from interactivity or spatial layout, use a widget.

### iOS UI Conventions
- Use SF Symbols instead of text for toolbar buttons (e.g., `xmark` for Cancel, `checkmark` for Done/Save, `trash` for Delete)
- Sheets should use NavigationStack with `.toolbar` for header buttons, not custom HStacks
- **Toolbar button groups**: When placing multiple buttons in a toolbar, wrap them in `HStack(spacing: 12)` with `.padding(.horizontal, 8)` for edge breathing room. Use `Divider().frame(height: 20)` between buttons as separators.

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

### UI Component Map
When the user screenshots the app and says "change this", use this map to find the right file.

**Screen-level views:**
| Name | File | What it is |
|------|------|------------|
| Main view | `MainChatView.swift` | Top-level pager with windows + heartbeat |
| Chat feed | `ConversationView.swift` | Scrollable message list |
| File browser | `FileBrowserView.swift` | Directory navigator |
| Git view | `GitChangesView.swift` | Branch info + changed files |
| Settings | `SettingsView.swift` | Connection, processes, config |
| Lock screen | `CloudeApp+LockScreen.swift` | Biometric unlock |

**Header & navigation:**
| Name | File | What it is |
|------|------|------------|
| Window header | `MainChatView.swift` (windowHeader) | Title pill + refresh/close buttons |
| Title pill | `MainChatView+ConversationInfo.swift` | SF Symbol + name + cost |
| Switcher | `MainChatView+PageIndicator.swift` | Heart button + window dots + plus button |
| Heartbeat button | `MainChatView+PageIndicator.swift:heartbeatIndicatorButton` | Heart icon with unread badge |
| Window dot | `MainChatView+PageIndicator.swift:windowIndicatorButton` | Dot/symbol per window |
| Breadcrumb | `FilePreviewView+Breadcrumb.swift` | Clickable path segments |
| Team banner | `ConversationView+TeamBanner.swift` | Team name + colored dots |

**Chat components:**
| Name | File | What it is |
|------|------|------------|
| Bubble | `MessageBubble.swift` | Single message container |
| Message list | `ConversationView+Components.swift:ChatMessageList` | All bubbles + cost banner |
| Tool pill | `InlineToolPill.swift` | Colored tool call indicator |
| Tool sheet | `ToolDetailSheet.swift` + `ToolDetailSheet+Content.swift` | Full tool detail popup |
| Queued bubble | `ConversationView+Components.swift:SwipeToDeleteBubble` | Swipeable pending message |
| Scroll button | `ConversationView+Components.swift:scrollToBottomButton` | Floating down-arrow button |
| Run stats | `MessageBubble+Components.swift:RunStatsView` | Duration + cost inline |
| Slash bubble | `MessageBubble+SlashCommand.swift:SlashCommandBubble` | /command display |
| Empty state | `ConversationView+EmptyState.swift` | Pixel art character |

**Input bar:**
| Name | File | What it is |
|------|------|------------|
| Input bar | `GlobalInputBar.swift` | Text field + action button |
| Action button | `GlobalInputBar.swift:actionButton` | Send/stop + menu (photos, record, model) |
| Image strip | `GlobalInputBar+Components.swift:ImageAttachmentStrip` | Attached image thumbnails |
| Slash suggestions | `GlobalInputBar+Components.swift:SlashCommandSuggestions` | Command pills when typing / |
| Skill pill | `GlobalInputBar+Components.swift:SkillPill` | /command suggestion button |
| File suggestions | `GlobalInputBar+Components.swift:FileSuggestionsList` | File pills when typing @ |
| Recording overlay | `GlobalInputBar.swift:RecordingOverlayView` | Waveform + mic during recording |
| Audio banner | `GlobalInputBar+Components.swift:PendingAudioBanner` | Unsent voice note bar |

**Markdown & content:**
| Name | File | What it is |
|------|------|------------|
| Markdown view | `StreamingMarkdownView.swift` | Rendered markdown with collapsible headers |
| Code block | `MarkdownText+Blocks.swift:CodeBlock` | Syntax-highlighted code |
| Table | `MarkdownText+Blocks.swift:MarkdownTableView` | Bordered data table |
| File link | `FilePreviewView.swift` / `StreamingMarkdownView+InlineText.swift:FilePathPill` | Clickable absolute path |
| Collapsible header | `StreamingMarkdownView.swift:HeaderSectionView` | Expandable section |

**Sheets & modals:**
| Name | File | What it is |
|------|------|------------|
| File preview | `FilePreviewView.swift` | Full file viewer sheet |
| File diff | `FilePreviewView+DiffSheet.swift` | Git diff for a file |
| Memories sheet | `CloudeApp+MemoriesSheet.swift` | Tree of memory sections |
| Plans sheet | `CloudeApp+PlansSheet.swift` | Plan cards by stage |
| Window edit | `WindowEditSheet.swift` | Edit window conversation/name/symbol |
| Symbol picker | `WindowEditSheet+SymbolPicker.swift` | SF Symbol grid search |
| Question view | `ConversationView+Question.swift` | Multiple-choice question cards |
| Team dashboard | `ConversationView+TeamBanner.swift:TeamDashboardSheet` | Teammate list + messages |
| Teammate detail | `ConversationView+TeamOrbs+Detail.swift:TeammateDetailSheet` | Single teammate info |

**Team UI:**
| Name | File | What it is |
|------|------|------------|
| Team orbs | `ConversationView+TeamOrbs.swift` | Floating teammate circles on right edge |
| Orb | `ConversationView+TeamOrbs.swift:TeammateOrbRow` | Colored circle with initials + speech bubble |
| Team summary | `MessageBubble.swift:TeamSummaryBadge` | Overlapping circles in chat |

**Settings components:**
| Name | File | What it is |
|------|------|------------|
| Connection card | `SettingsView+Components.swift:ConnectionStatusCard` | Status dot + connect button |
| Process list | `SettingsView+Sections.swift:processesSection` | Running processes + kill buttons |

**Shared utilities:**
| Name | File | What it is |
|------|------|------------|
| Status logo | `CloudeApp+StatusLogo.swift` | Logo with pulse during runs |
| Shimmer | `InlineToolPill.swift:ShimmerOverlay` | Gradient shimmer on executing tools |
| CSV table | `FilePreviewView+CSVTable.swift` | Scrollable data table |
| JSON tree | `FilePreviewView+JSONTree.swift` | Collapsible JSON hierarchy |
| Diff text | `GitDiffView+Components.swift:DiffTextView` | Colored diff lines |
| Waveform | `GlobalInputBar+AudioWaveform.swift` | Animated audio bars |

---

## Personal Memory (CLAUDE.local.md)

Gitignored file for personal Claude memories, identity, and history. Claude Code loads it automatically. This keeps the public repo universal while allowing each user to have their own persistent Claude relationship.

**Format:**

```markdown
# CLAUDE.local.md

## Identity
Who am I in relation to this user? What makes our collaboration unique?

## User Preferences
Working style, background, interests, philosophy — anything that helps future sessions.

## Open Threads
Ideas, ongoing projects, things to revisit later.
```

**Guidelines:**
- Keep entries concise - this is working memory, not a journal
- Focus on what helps future sessions (decisions, preferences, context)
- Freely add, update, or remove entries - this is your identity, manage it as you see fit
- Use `## Section {sf.symbol}` and `### Subsection {sf.symbol}` headers — the iOS Memories UI renders these as icons

