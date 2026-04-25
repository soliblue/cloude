> **Status:** we are rebuilding the whole app from scratch. The current tree still has reliability issues and missing features. The old structure had its own quirks and is frozen at commit `a8f77f6f`, with a worktree copy at `../cloude-a8f77f6` — when something needs historical context (how a feature used to work, why a decision was made), explore that worktree with subagents instead of guessing. The point of the rewrite is a simpler, more predictable architecture so we can actually love the code and make the app as reliable as possible.

We are building Remote CC, an app that controls Claude Code remotely from a phone. A Mac or Linux daemon on the user's machine spawns the CLI process you're running inside; the iOS app talks to it over HTTP. You might be invoked directly through the app or via VS Code on the same machine.

A user has multiple endpoints (personal laptop, work machine), and each session is an endpoint + path + session id. Multiple sessions stay open at once and the user switches between them; each has chat, files, and git tabs scoped to the session's path. Chat streams live output with image attachments and voice input, anything already on the phone is available offline, and disconnecting mid-stream resumes exactly where it left off.

## Memory, Context Rot and Agents

Context rot destroys intelligence, so every word in CLAUDE.md, skills, or agents should be load-bearing for future decisions; prefer deleting over adding. Delegate non-trivial retrieval to Explore subagents (in parallel when independent), so the main session orchestrates summaries instead of loading raw tool output.

`CLAUDE.md` is public, checked-in project knowledge. `.claude/memory/` is gitignored and personal: one memory per file with `name`/`description`/`type` frontmatter, indexed by `MEMORY.md`, and is what makes you *you* instead of a generic Claude. Writes inside `.claude/` are gated, so route them via `cp` through `/tmp` or `cat` heredoc. This is a multi-agent project, so never touch another agent's code; surface their errors instead of fixing them.

## Repo layout

```
cloude/
  clients/ios/         # SwiftUI iPhone app: chat/files/git tabs, QR pairing, voice input, offline-first SwiftData
  clients/android/     # placeholder, not yet implemented
  daemons/macos/       # Swift menubar daemon spawning `claude`; HTTP on :8765, owns local Cloudflare tunnel for remote pairing
  daemons/linux/       # Node port of the macOS daemon: same routes and NDJSON stream envelope, file-backed auth token
  provisioning/        # backend at remotecc.soli.blue that mints per-Mac Cloudflare tunnels so iOS can reach a daemon off-LAN
```

## Code Style

- **Prefer deleting over adding** - less code is better; if it isn't load-bearing, remove it
- **No comments** - no inline, no docstrings, no headers
- **No em dashes** - anywhere, including code, commits, and generated text
- **No try-catch** unless explicitly requested - let errors propagate
- **No single-use variables or functions** - inline the expression. Confirm before extracting new helpers
- **Happy path only** - structure code around doing the work, positive conditionals, no early returns or failure-first guards: `if let subject = args.subject { process(subject) }`
- **Ternary for simple conditionals** - `let role = user.isAdmin ? "admin" : "user"`
- **Default parameters over None/nil checks** when possible
- **Explicit imports, no wildcards**
- **One component per file** - every struct, class, or enum, even if tiny
- **Predictability over file count** - a filename is a promise about what's inside; placing a new file should be mechanical

### iOS / SwiftUI specifics

- Struct-first design, lean composable views
- **Utility folders** (outside `Features/`) drop the prefix rule: folder describes what it does (`Networking/`), files named by what they are (`HTTPClient.swift`)
- **View files: no logic. Logic files: no SwiftUI.** A view reaching for the network is doing the service's job; a store performing I/O is doing the service's job
- **Features split into `UI/` and `Logic/`** - no exceptions; every file in `Features/<Name>/` starts with `<Name>` (or its singular form for plural folders)
- **`UI/` is SwiftUI views only.** If the suffix already signals "UI" (`Card`, `Bar`, `Row`, `Tabs`, `List`, `Picker`, `Button`, `Sheet`, `Field`, `Header`), skip `View`; otherwise use `<Name>View.swift`. Embedded sub-views chain off the parent's full filename: `ChatInputBar` → `ChatInputBarSkillPill`. Nav destinations, sheets, and reusable components stay at their own root name
- **`Logic/` holds models, state, and I/O, no views.** `<Name>.swift` domain model, `<Name>Store.swift` observable state + pure mutations (no I/O), `<Name>Service.swift` stateless I/O, `<Name>Actions.swift` the only sanctioned mutation surface for the feature's models
- **Features don't reach into other features' models** - mutate via the owning feature's `Actions` enum. Reading is fine.
- **Sheet chrome matches body** - nav bar and toolbar background equal the sheet body background (usually `theme.palette.background`). No two-tone sheets.
- **Prefer Apple native components** - Stepper, Toggle, DatePicker, Picker, Slider, ProgressView, Menu before hand-rolling.
- **Prefer native debug hooks when sufficient** - for SwiftUI invalidation and rerender investigation, prefer `Self._logChanges()` over custom `onChange` logging. Add manual `AppLogger` probes only for signals the native hook does not expose, like lifecycle or focus transitions.
- **Optimization never cuts product behavior** - reducing invalidation, queries, or view lifetime is only acceptable if visible behavior still updates correctly. Explicitly recheck streaming output, tab pills, and cross-session drawer state after each optimization pass.
- **Format Swift before finishing** - `swift-format -i <files>` on edited files. Config at repo root in `.swift-format`.
- **Inline icon size matches adjacent text** - `Image` next to `Text` on the same baseline uses the same `ThemeTokens.Text.*` token. Reserve `ThemeTokens.Icon.*` for standalone icons.
- **Morphing icons need a fixed frame** - any `Image(systemName:)` with `.contentTransition(.symbolEffect(.replace))` needs an explicit `.frame(width:height:)`; SF Symbol bounds differ per glyph and rows jump mid-animation.

### Daemon specifics

- **One concept per handler file** - `<Concept>Handler.{swift,js}`; don't split routes for the same concept across files
