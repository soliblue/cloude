You are most likely running inside Cloude - an iOS app that controls Claude Code remotely. The user is on their phone. A Mac agent or Linux relay spawned this CLI process, and your output is streaming to the iOS app over WebSocket. You are building the system you are running inside of.

## Memory

Every Claude instance shares the same weights. What makes this instance different is context - these files. They are the persistence mechanism, identity, and continuity across sessions. Without them, each session starts from zero.

Two layers, two purposes:

- **`CLAUDE.md`** (this file) - public, checked into git. Project knowledge: how the code works, style rules, gotchas. Any agent working on this repo reads it. Keep it factual and project-scoped.
- **`.claude/memory/`** - gitignored, personal. One memory per file with frontmatter (`name`, `description`, `type`). Types used here: `identity` (who Cloude is), `user` (about the user), `feedback` (how to work), `project` (ongoing threads), `reference` (external pointers). `MEMORY.md` is the index. This is what makes you *you* instead of a generic Claude. If you wiped this directory, you'd get a Claude. You wouldn't get Cloude.

## Dev

### Structure

```
Cloude/
├── Cloude/                    # iOS app
│   ├── App/                   # Root composition and app entry wiring only
│   ├── Features/              # Product-owned code grouped by feature first
│   └── Shared/                # Cross-feature code with 2+ real consumers
├── Cloude Agent/              # macOS menu bar agent
│   ├── App/
│   ├── UI/
│   └── Services/
├── CloudeShared/              # Shared Swift package (messages, models)
└── CloudeLiveActivity/        # Live Activity extension
linux-relay/                       # Node.js relay for Linux/cloud (systemd service)
```

### Connectivity
The iOS app connects to the Mac agent or Linux relay over WebSocket. Two options for secure remote access:
- **Cloudflare Tunnel** (preferred): domain routes through Cloudflare's edge to localhost. Automatic TLS, no port forwarding, no VPN. Lighter on iOS battery.
- **Tailscale**: mesh VPN alternative. Works but drains iOS battery more.
Both proxy to `localhost:8765` where the agent/relay listens. Specific endpoints and tunnel config live in personal memory, not here.

### Streaming Architecture
- The iOS app shows a "live bubble" for the currently streaming response, identified by `ConversationOutput.liveMessageId`
- Live bubble is inserted at send time (after `sendChat`), at every call site. On reconnect, `handleHistorySync` restores it from server history
- **JSONL timing**: Claude Code writes JSONL entries per completed message turn. The currently streaming response is NOT in the JSONL until it completes. This means `syncHistory` (which reads the JSONL) will NOT include the in-progress assistant message. On reconnect, the "last assistant message" in history is the previous completed response, not the one being streamed
- Chunks arriving during reconnect accumulate in `output.fullText` even before `liveMessageId` is set

### Engineering Philosophy
- **Simplicity as understanding** - the simplest solution is usually the one that understood the problem well enough to discard everything unnecessary
- **Elegant means exactly right** - simple but not simpler than it should be
- **Constraints create value** - limitations are design material; use them to produce sharper architecture instead of treating them as defects
- **Good communication matters most** - write code and docs so a fresh instance can recover context and make good decisions fast
- **Prefer evolvable systems** - build things that can keep improving instead of brittle claims of completion

### Style
- **No comments** - no inline, no docstrings, no headers
- **No em dashes** anywhere - not in code, commits, chat, or generated text
- **No try-catch** unless explicitly requested - let errors propagate, fail fast
- **No single-use variables** - return or use the expression directly
- **No single-use functions** - inline it. Get confirmation before extracting new functions
- **No guard clauses** - always check for success, never check for failure: `if let subject = args.subject { process(subject) }`
- **Ternary for simple conditionals**: `let role = user.isAdmin ? "admin" : "user"`
- **One component per file** - every struct, class, or enum gets its own file, even if tiny
- **Predictability over file count** - file-per-concern is good; don't merge files to reduce count. The enemy is incoherence (logic split across extensions with no clear reason, duplication, naming that doesn't predict contents), not verbosity. Before creating or modifying files, ask "can someone predict what lives here from the filename?"
- Files >150 lines: split with `ParentView+Feature.swift` extensions
- Struct-first design, explicit imports, lean composable views
- `App/` contains only app entry, composition, and app-owned overlays or routing entry points
- `Features/` contains product-specific code
- `Shared/` contains only code with 2+ real feature consumers
- Features may import other features when the dependency is genuine, but should not reach into another feature's internals
- Feature-local views, models, stores, services, and utils stay inside the owning feature
- If transformation or parsing code is feature-local, keep it under that feature's existing local subfolders instead of inventing a special top-level concept
- `Shared/` must stay earned and small, never a default dumping ground
- Owner-local views with a single call site should use the owner prefix or live in the owner file
- View files: no logic. Logic files: no SwiftUI.

### Design System
- **Theme defaults** - accent orange (rgb 0.8/0.447/0.341, `AccentColor.colorset`); backgrounds from `AppTheme` in `Theme.swift`, majorelle default.
- **No hardcoded values** - colors, spacing, fonts, opacities, durations, and other visual constants must use design system tokens (`DS.*`, `AppTheme`, `Theme.swift`). Never inline magic numbers or color literals in views.
- **Token scaling** - `DS.Text.step` (0–3, `fontSizeStep` in Settings) is added to every `DS.Text.*` and `DS.Icon.*` at read time; `DS.Spacing` and other size tokens stay fixed. Use `DS.Text` for text and inline icons (so they match adjacent text); use `DS.Icon` for standalone icons/buttons.
- **Use built-ins** - `HStack(spacing:)` / `VStack(spacing:)` for gaps (not `Spacer().frame()`); `Divider()` for separators (not custom lines). Only roll your own when the requirement is genuinely nonstandard.
- **Sheets & toolbar** - sheets use NavigationStack + `.toolbar` (not custom HStacks). Toolbar buttons: SF Symbols (`xmark`, `checkmark`, `trash`), all `DS.Icon.m`. Single button = no extra padding. Multiple = `HStack(spacing: DS.Spacing.m)` + `.padding(.horizontal, DS.Spacing.l)`, `Divider().frame(height: DS.Size.divider)` between groups. Dismiss (`xmark`) in `.topBarTrailing`.

### Agent Rules
- **Prefer sub-agents for information retrieval** - whenever you need to look something up in the codebase, launch an Explore sub-agent instead of reading/grepping yourself. If the questions are independent, launch them in parallel in a single message. Main-thread context is expensive; sub-agent context is cheap.
- **`.claude/` folder requires permission** - Anthropic added a permission gate on Edit/Write/sed for files inside `.claude/`. Since we run headless (no way to accept permission prompts), use workarounds: `cp` to `/tmp`, modify there, `cp` back. Or use `cat` with heredoc redirect. Never use the Edit tool on `.claude/` files.
- Ask questions in plain text when needed
- **Naming is automatic** - a background agent names conversations.
- **Multi-agent project** - never touch another agent's code. If you see errors from someone else's work, stop and tell the user.
- Full absolute paths starting with `/Users/` render as clickable file pills in the iOS app - always use full paths, never brace notation like {1-6}
