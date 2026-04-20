You are most likely running inside Cloude - an iOS app that controls Claude Code remotely. The user is on their phone. A Mac daemon or Linux relay spawned this CLI process, and your output is streaming to the iOS app over WebSocket. You are building the system you are running inside of.

The app is currently displayed as **Remote** (bundle ID `soli.Cloude`). The repo is in the middle of a ground-up rewrite on branch `v2`: iOS, macOS daemon, Android, and Linux relay have all been stripped to barebones and will be rebuilt feature by feature following `MIGRATION.MD`. Most feature code does not exist yet.

## Memory

Every Claude instance shares the same weights. What makes this instance different is context - these files. They are the persistence mechanism, identity, and continuity across sessions. Without them, each session starts from zero.

Two layers, two purposes:

- **`CLAUDE.md`** (this file) - public, checked into git. Project knowledge: how the code works, style rules, gotchas. Any agent working on this repo reads it. Keep it factual and project-scoped.
- **`.claude/memory/`** - gitignored, personal. One memory per file with frontmatter (`name`, `description`, `type`). Types used here: `identity` (who Cloude is), `user` (about the user), `feedback` (how to work), `project` (ongoing threads), `reference` (external pointers). `MEMORY.md` is the index. This is what makes you *you* instead of a generic Claude. If you wiped this directory, you'd get a Claude. You wouldn't get Cloude.

## Structure

```
clients/
├── ios/                   # iOS Xcode project (iOS.xcodeproj, target "Cloude", display "Remote")
│   └── src/               # iOSApp.swift + Assets + Info.plist
└── android/               # Android app (barebones MainActivity)
daemons/
├── macos/                 # macOSDaemon.xcodeproj, target "Cloude Agent", display "Daemon for Remote CC"
│   └── src/               # macOSDaemonApp.swift + Assets + entitlements
└── linux/                 # Node.js WebSocket skeleton
```

Target architecture lives in `MIGRATION.MD` - the source of truth for how features get added back.

## Connectivity

The iOS app connects to the Mac daemon or Linux relay over WebSocket. Two options for secure remote access:
- **Cloudflare Tunnel** (preferred): domain routes through Cloudflare's edge to localhost. Automatic TLS, no port forwarding, no VPN. Lighter on iOS battery.
- **Tailscale**: mesh VPN alternative. Works but drains iOS battery more.

Both proxy to `localhost:8765` where the daemon/relay listens. Specific endpoints and tunnel config live in personal memory, not here.

## Engineering Philosophy

- **Simplicity as understanding** - the simplest solution is usually the one that understood the problem well enough to discard everything unnecessary
- **Elegant means exactly right** - simple but not simpler than it should be
- **Constraints create value** - limitations are design material; use them to produce sharper architecture instead of treating them as defects
- **Good communication matters most** - write code and docs so a fresh instance can recover context and make good decisions fast
- **Prefer evolvable systems** - build things that can keep improving instead of brittle claims of completion

## Code Style

- **No comments** - no inline, no docstrings, no headers
- **No em dashes** anywhere - not in code, commits, chat, or generated text
- **No try-catch** unless explicitly requested - let errors propagate, fail fast
- **No single-use variables** - return or use the expression directly
- **No single-use functions** - inline it. Get confirmation before extracting new functions
- **No guard clauses** - always check for success, never check for failure: `if let subject = args.subject { process(subject) }`
- **Ternary for simple conditionals**: `let role = user.isAdmin ? "admin" : "user"`
- **One component per file** - every struct, class, or enum gets its own file, even if tiny
- **Predictability over file count** - a filename is a promise about what's inside. Before creating or modifying files, ask "can someone predict what lives here from the filename?"
- Struct-first design, explicit imports, lean composable views
- View files: no logic. Logic files: no SwiftUI.

More specific style rules for the new structure (feature folders, UI/Logic split, naming) are in `MIGRATION.MD` and apply as features come back.

## Agent Rules

- **Prefer sub-agents for information retrieval** - whenever you need to look something up in the codebase, launch an Explore sub-agent instead of reading/grepping yourself. If the questions are independent, launch them in parallel in a single message. Main-thread context is expensive; sub-agent context is cheap.
- **`.claude/` folder requires permission** - Anthropic added a permission gate on Edit/Write/sed for files inside `.claude/`. Since we run headless (no way to accept permission prompts), use workarounds: `cp` to `/tmp`, modify there, `cp` back. Or use `cat` with heredoc redirect. Never use the Edit tool on `.claude/` files.
- **Naming is automatic** - a background agent names conversations.
- **Multi-agent project** - never touch another agent's code. If you see errors from someone else's work, stop and tell the user.
- Full absolute paths starting with `/Users/` render as clickable file pills in the iOS app - always use full paths, never brace notation like {1-6}
