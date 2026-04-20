You are most likely running inside Cloude - an iOS app that controls Claude Code remotely. The user is on their phone. A Mac daemon or Linux relay spawned this CLI process, and your output is streaming to the iOS app over WebSocket. You are building the system you are running inside of.

The app is currently displayed as **Remote** (bundle ID `soli.Cloude`). The repo is in the middle of a ground-up rewrite on branch `v2`: iOS, macOS daemon, Android, and Linux relay have all been stripped to barebones and are being rebuilt feature by feature. Most feature code does not exist yet.

## Migration status

We are mid-migration from the old app. The pre-wipe codebase is checked out as a sibling worktree at `/Users/soli/Desktop/CODING/cloude-main` (branch `main`). Use it as a reference when rebuilding a feature - copy what's worth keeping, drop what isn't, match the old visual style when the user asks for parity.

Progress is tracked by ticks (✅) next to filenames in the structure below. A tick means the file exists in `v2`. No tick means it's planned but not built yet. When you add or remove files, update the ticks in this document so fresh sessions can see where we are.

## Memory

Every Claude instance shares the same weights. What makes this instance different is context - these files. They are the persistence mechanism, identity, and continuity across sessions. Without them, each session starts from zero.

Two layers, two purposes:

- **`CLAUDE.md`** (this file) - public, checked into git. Project knowledge: how the code works, style rules, gotchas. Any agent working on this repo reads it. Keep it factual and project-scoped.
- **`.claude/memory/`** - gitignored, personal. One memory per file with frontmatter (`name`, `description`, `type`). Types used here: `identity` (who Cloude is), `user` (about the user), `feedback` (how to work), `project` (ongoing threads), `reference` (external pointers). `MEMORY.md` is the index. This is what makes you *you* instead of a generic Claude. If you wiped this directory, you'd get a Claude. You wouldn't get Cloude.

## Product shape

- multiple environments (personal laptop, work machine, etc)
- session = environment + path + session id
- multiple sessions open at once, switch between them
- each session has 3 tabs: chat, files, git
- chat streams live output from claude, with image attachments and voice input
- files/git scoped to the session's path
- offline access to anything already on the phone
- seamless reconnect: disconnect mid-stream and pick up exactly where you left off

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
- **Features don't reach into other features' models** - if feature A needs to create, mutate, or delete a model owned by feature B, it calls B's `Actions` enum. A feature's `Actions` is the only sanctioned mutation surface for its models; cross-feature `context.insert(OtherModel(...))` or direct field writes on another feature's model are off-limits. Reading another feature's model (e.g. SwiftData relationships, `@Query`) is fine.
- **Sheet chrome matches body** - a sheet's nav bar and toolbar background must be the same as the sheet's body background (usually `theme.palette.background` via `@Environment(\.theme)`). No two-tone sheets.
- **Prefer Apple native components** - use SwiftUI/UIKit native controls (Stepper, Toggle, DatePicker, Picker, Slider, ProgressView, Menu, etc.) before hand-rolling equivalents. Native gets disabled endpoints, haptics, accessibility, and platform idiom for free. Only go custom when the native control genuinely can't do what's needed.
- **Format Swift before finishing** - after editing any `.swift` file, run `swift-format -i <files>` on the files you touched. Config lives at repo root in `.swift-format`. Never commit unformatted Swift.

## Naming

A file's path predicts its contents. Placing a new file is mechanical, not a judgment call. The rules below apply everywhere in the repo; if a file doesn't fit, it belongs in a different folder.

### feature folders (`Features/<Name>/`)
Every feature splits into `UI/` and `Logic/`. No exceptions - even features with only a couple files. Keeps each subfolder short and makes the UI/state boundary impossible to blur.

Every file starts with `<Name>` - or its singular form if `<Name>` is plural (so `Environments/` accepts `Environment*` or `Environments*`, `Files/` accepts `File*` or `Files*`). Role suffix tells you what it is and which subfolder it lives in:

`UI/` - SwiftUI views only, no state or I/O. Naming heuristic: if the suffix word already signals "this is UI" (`Card`, `Bar`, `Row`, `Tabs`, `List`, `Picker`, `Button`, `Sheet`, `Field`, `Header`), skip `View`. Otherwise add it.
- `<Name>View.swift` - bare feature name (`ChatView`, `SessionView`) or generic modifier where no UI suffix fits
- `<Name><UISuffix>.swift` - self-evident UI suffix (`EnvironmentsList`, `ChatInputBar`, `SessionsListRow`)
- `<Name>Sheet.swift` - modally-presented content (`FileViewerSheet`, `GitDiffSheet`). Sheet is in the suffix list above, so `View` is dropped.

**Hierarchy prefix for embedded sub-views.** If a view only exists inside another view, its filename starts with the parent's **full filename** (including any `View` suffix on the parent). The pattern chains: `ChatInputBar` → `ChatInputBarSkillPill`, `SessionView` → `SessionViewTabs` → (further nesting would chain again). This makes ownership obvious and groups siblings alphabetically under the parent. Nav destinations, sheets, and reusable components stay at their own root name.

`Logic/` - state, models, and I/O; no views:
- `<Name>.swift` - domain model / entity (`Environment.swift`, `ChatMessage.swift`)
- `<Name>Store.swift` - observable state + pure mutations (`add`, `update`, `remove`, `get`). No network, no side effects
- `<Name>Service.swift` - stateless I/O (network, disk). Returns values; callers write to the store

If a file doesn't start with the feature name, it doesn't belong in that folder. If a view reaches for the network, it's doing the service's job; if a store performs I/O, it's doing the service's job.

### utility folders (outside `Features/`)
Not product features, so no prefix rule. Folder name describes what it does (`Networking/`, `Notifications/`). Files inside are named by what they are (`HTTPClient.swift`, `StreamingClient.swift`, `NotificationService.swift`).

### daemon handlers (`MacApp/Handlers/`)
Every file is `<Concept>Handler.swift` and owns one route group. One handler = one concept. Don't split routes for the same concept across files.

### one concept per file
A filename is a promise about what's inside. Never merge unrelated things to save lines - the cost is paid every time someone reads or edits. Before writing a new file, ask: can someone predict what lives here from the name alone? If not, rename it.

## Repo layout

```
cloude/
  clients/
    ios/
    android/
  daemons/
    macos/
    linux/
```

## iOS structure

Feature-based. Each feature owns its views, models, stores, services.

```
src/
  Features/
    Endpoints/
      UI/
        EndpointsCarousel.swift      ✅  // horizontal TabView (.page style) shown inline inside the Settings sheet; last page is EndpointsCarouselAdd
        EndpointsCarouselCard.swift        ✅  // composes CardHeader + CardForm for one endpoint; binds host/port/token and reads status. mutates store via Binding
        EndpointsCarouselCardHeader.swift  ✅  // symbol button + status dot/label + trash (hidden when only 1 endpoint) + power (ping); pulsing power icon while checking
        EndpointsCarouselCardForm.swift    ✅  // host, port, auth key fields; writes token to Keychain via SecureStorage keyed on endpoint.id
        EndpointsCarouselAdd.swift         ✅  // "+" page that appends a blank Endpoint via a callback
        EndpointsSymbolPicker.swift        ✅  // sheet presented from the card's symbol button; searchable LazyVGrid of SF Symbols grouped by category
      Logic/
        Endpoint.swift                 ✅  // @Model: id, host, port, symbolName, createdAt; @Transient status. authKey NOT on the model, lives in Keychain under id.uuidString
        EndpointStatus.swift           ✅  // enum: .unknown | .checking | .reachable | .unreachable; exposes a semantic color
        EndpointService.swift          ✅  // stateless; GET /ping with Bearer authKey, mutates endpoint.status directly
        EndpointActions.swift          ✅  // stateless mutations on the Endpoint model: add, remove (deletes Keychain entry + the model), saveAuthKey (no-op if the endpoint was deleted), seedDev (DEBUG-only env-var dev-endpoint seed, called from iOSApp.init)
        EndpointsSymbolCatalog.swift   ✅  // static list of SF Symbol names grouped by category, consumed by EndpointsSymbolPicker
    Sessions/
      UI/
        SessionView.swift            ✅  // owns its top bar (SessionViewTabs) and body. Takes a Session directly. Currently a "coming soon" placeholder; real tab bodies land later. Owns @State activeTab.
        SessionViewTabs.swift        ✅  // 3-tab pill switcher (chat | files | git); rendered inside SessionView's top bar. Bound to SessionView's activeTab.
      Logic/
        Session.swift                ✅  // @Model: id (client-generated, passed to claude as --session-id), endpoint: Endpoint? (SwiftData relationship), path?, lastOpenedAt, title ("Untitled"), symbol ("sparkles"); @Transient skills?, agents? (fetched on demand). path == nil is the empty-state signal.
        SessionTab.swift             ✅  // enum: chat | files | git; each case has label + SF symbol
        SessionActions.swift         ✅  // stateless mutations on the Session model: add (inserts a Session with defaults and returns it). Owns session-creation logic so callers like WindowActions don't.
        Skill.swift                  ✅  // name, description. available in session's cwd; read by ChatInputBarAutocompletePicker via "/"
        Agent.swift                  ✅  // name, description. available in session; read by ChatInputBarAutocompletePicker via "@"
        // SessionService.swift — land when SessionHandler exists on the daemon
    Chat/
      UI/
        ChatView.swift                                // chat tab container: ChatViewMessageList on top, ChatInputBar pinned bottom
        ChatViewMessageList.swift                     // scrolling list of ChatViewMessageListRow, auto-scrolls as events arrive
        ChatViewMessageListRow.swift                  // one row = one ChatMessage; renders role, markdown body, tool pills, attachments
        ChatViewMessageListRowToolPillList.swift      // horizontal list of tool call pills on a message
        ChatViewMessageListRowToolPillListRow.swift   // one tool call pill - tool name, state dot, tap to expand args/result
        ChatViewMessageListRowAttachmentList.swift    // horizontal list of image attachments on a message
        ChatViewMessageListRowAttachmentListRow.swift // one attachment thumbnail; tap opens full-size viewer
        ChatInputBar.swift                            // text field (hosts inline pills), send button, attachments button; swipe-up gesture drives AudioRecorder and presents AudioInputOverlay
        ChatInputBarSkillPill.swift                   // inline chip for a selected skill (from "/" autocomplete)
        ChatInputBarAgentPill.swift                   // inline chip for a selected agent (from "@" autocomplete)
        ChatInputBarAutocompletePicker.swift          // popover triggered by "/" (skills) or "@" (agents)
        ChatInputBarAttachmentPicker.swift            // picks images from photos/files; opened from the attachments button
      Logic/
        ChatMessage.swift            // sessionId, role, text, tool calls, attachments, state, per-message stats
        ChatToolCall.swift           // tool name, args, result, state (pending/succeeded/failed)
        ChatStreamEvent.swift        // decoded ndjson event: system/init, stream_event, assistant, user, result
        ChatMarkdownParser.swift     // incremental parser: code fences, tool pills, tables - fed stream_event deltas
        ChatStore.swift              // @Published [sessionId: [ChatMessage]]; persisted per-session jsonl for offline. pure state.
        ChatService.swift            // streams /sessions/:id/chat; parses ndjson, routes to ChatStore. start/resume/reconcileAll/abort
    Audio/
      UI/
        AudioInputOverlay.swift      // covers input bar during recording + transcribing; 7-bar waveform fed by AudioRecorder.level; spinner during AudioService.transcribe
      Logic/
        AudioRecorder.swift          // AVAudioRecorder (16kHz mono PCM WAV), 50ms level polling. stateful device wrapper - the only non-Store/Service type allowed in Logic/
        AudioService.swift           // stateless; POST /audio → String
    Files/
      UI/
        FilesView.swift              // files tab: tree browser scoped to the session's path
        FileViewerSheet.swift        // single-file viewer. dispatches by MIME: .json → pretty tree; code → syntax-highlighted chunked viewer; .md → rendered markdown; images → AsyncImage; video/audio → AVPlayer (daemon honors Range); fallback → plain text
      Logic/
        FileNode.swift               // sessionId, path, name, isDirectory, children?
        FilesStore.swift             // @Published tree per session; persisted to disk per session. pure state.
        FilesService.swift           // stateless; list/read/search network I/O
    Git/
      UI/
        GitView.swift                // git tab: branch header, ahead/behind counts, list of changes; tap for diff
        GitDiffSheet.swift           // unified diff for one file (staged or unstaged); presented as a sheet from GitView
      Logic/
        GitChange.swift              // path, changeType (added/modified/deleted/renamed/untracked), staged
        GitStatus.swift              // sessionId, branch, ahead, behind, [GitChange]
        GitCommit.swift              // sha, author, date, subject
        GitStore.swift               // @Published status per session; persisted to disk per session. pure state.
        GitService.swift             // stateless; status/diff/log network I/O
    Windows/
      UI/
        WindowsView.swift            ✅  // top-level screen: theme background + active SessionView + WindowsViewSwitcher pinned at the bottom + top-leading SettingsButton (owns the settings sheet) + DebugOverlay
        WindowsViewSwitcher.swift    ✅  // bottom-of-screen horizontal scroll of WindowsViewSwitcherPill + a trailing "+" to spawn a new session via WindowActions.addNew
        WindowsViewSwitcherPill.swift ✅  // one pill for a Window/Session pair. tap = activate, long-press = close. Title truncates at maxNameLength (10) with ellipsis
      Logic/
        Window.swift                 ✅  // @Model: session: Session? (SwiftData relationship), order: Int, isFocused: Bool. One Window per open pill in the switcher.
        WindowActions.swift          ✅  // stateless mutations on the Window model: ensureOne (called from iOSApp.init), activate, addNew, close. addNew/ensureOne insert a matching Session alongside the Window; close deletes only the Window (Session persists for re-opening from SessionsList). Keeps WindowsViewSwitcher view body logic-free.
    Settings/
      UI/
        SettingsButton.swift                     ✅  // hamburger icon that opens SettingsView as a sheet
        SettingsRow.swift                        ✅  // row primitives: SettingsRow (colored-icon + content) and SettingsToggleRow (row bound to an @AppStorage bool key)
        SettingsView.swift                       ✅  // top-level settings sheet: NavigationStack + List of sections + trailing xmark dismiss
        SettingsViewAbout.swift                  ✅  // version + external links section
        SettingsViewFontSize.swift               ✅  // -/+ stepper bound to @AppStorage("fontSizeStep")
        SettingsViewTheme.swift                  ✅  // row that navigates to SettingsViewThemePicker
        SettingsViewThemePicker.swift            ✅  // 2-col LazyVGrid of theme cards; private SettingsViewThemePickerCard nested in file
      Logic/
        // no SettingsStore yet - theme lives in Core/Theme/ThemeStore, fontSizeStep in @AppStorage. Add a store if a third setting shows up.
  Core/
    Debug/
      DebugOverlay.swift             ✅  // top-trailing pill showing FPS when @AppStorage("debugOverlayEnabled") is true
      DebugFPSCounter.swift          ✅  // ObservableObject driven by CADisplayLink; @Published fps recomputed every second
    Networking/
      HTTPClient.swift               ✅  // stateless GET/POST with Bearer auth; returns (Data, HTTPURLResponse)? (nil on transport error)
      StreamingClient.swift          // ndjson reader with resume-on-disconnect via after_seq
    Storage/
      SecureStorage.swift            ✅  // Keychain wrapper: get/set/delete keyed by account string (scoped to service "soli.Cloude.environments"); used for per-endpoint auth tokens
      StorageKey.swift               ✅  // shared @AppStorage key constants (fontSizeStep, debugOverlayEnabled, wrapCodeLines, appTheme)
    Notifications/
      NotificationService.swift      // local notification when a run completes in background
    Theme/
      Theme.swift                    ✅  // enum Theme (presets) + nested Palette struct (background/surface/elevated/colorScheme)
      ThemeColor.swift               ✅  // semantic color aliases (blue/cyan/success/danger/etc.) + Color(hex:) initializer
      ThemeTokens.swift              ✅  // design tokens: Text/Icon/Spacing/Radius/Size/Scale/Stroke/Duration/Delay/Opacity
      ThemeEnvironment.swift         ✅  // EnvironmentValues.theme + .fontStep + .appFont(size:weight:design:) + .themedNavChrome() modifiers
  iOSApp.swift                       ✅  // @main App; constructs the SwiftData ModelContainer (Endpoint/Session/Window), calls EndpointActions.seedDev + WindowActions.ensureOne at init, renders WindowsView with .modelContainer injected and theme/fontStep AppStorage
```

## macOS daemon

Regular macOS app exposing an HTTP listener. Handlers map 1:1 to routes. Runner manager holds the only piece of server-side state.

```
src/
  Handlers/
    ChatHandler.swift
      // every outgoing ndjson event carries a monotonic `seq` per session. RunnerManager keeps a ring buffer
      // of recent events (live turn + ~60s after exit) and an in-memory record of whether a claude process is
      // currently alive - the oracle for "still running vs. done", since jsonl only gets the assistant line
      // once the turn completes.
      POST /sessions/:id/chat         start()      // spawn `claude -p --session-id <id> --output-format stream-json --verbose --disallowedTools AskUserQuestion ExitPlanMode EnterPlanMode` (or --resume if session exists), pipe prompt+images to stdin, stream ndjson. if a turn is already running for this session, aborts it first.
        in   {path, prompt, images?: [{data: base64, mediaType: "image/png|jpeg|webp|gif"}]}
        out  application/x-ndjson  {seq, sessionId, ...}
      GET  /sessions/:id/chat/resume  resume()     // single reconcile endpoint. takes ?message_id=msg_...&after_seq=N. always returns ndjson.
                                                   //   process alive → replay ring events > after_seq, then tail live until terminal
                                                   //   process gone + jsonl has message_id → one synthetic event, state=completed
                                                   //   process gone + jsonl missing → one synthetic event, state=failed
      POST /sessions/:id/chat/abort   abort()      // SIGINT the running claude process; emits a final `aborted` event on the stream
    FilesHandler.swift
      GET  /sessions/:id/files         list()       // list directory under the session path
      GET  /sessions/:id/files/:path   read()       // read a file (chunked for large files)
      GET  /sessions/:id/files/search  search()     // filename search under the session path
    GitHandler.swift
      GET  /sessions/:id/git/status   status()     // branch, ahead/behind, file statuses
      GET  /sessions/:id/git/diff     diff()       // staged or unstaged diff for a file or whole repo
      GET  /sessions/:id/git/log      log()        // recent commits
    SessionHandler.swift
      POST /sessions/:id/title     generateTitleAndSymbol()  // one-shot `claude -p --model sonnet --output-format json` with meta prompt over user's first prompt
        in   {prompt}
        out  {title, symbol}
      GET  /sessions/:id/skills    skills()         // project + user skills merged
        out  [{name, description}]
      GET  /sessions/:id/agents    agents()         // agents available in the session
        out  [{name, description}]
    AudioHandler.swift
      POST /audio    transcribe()          // audio blob in, transcribed text out
    PingHandler.swift         ✅  // GET /ping, returns {"ok": true} for reachability checks
  Networking/
    HTTPRequest.swift         ✅  // parsed request: method, path, query, headers (lowercased keys), body
    HTTPResponse.swift        ✅  // status + body + content-type; .json(status:object:) helper; serializes to raw HTTP/1.1 bytes
    HTTPServer.swift          ✅  // NWListener on port 8765; reads headers+body (1MB cap), routes through Router
  Routing/
    Router.swift              ✅  // dispatches (method, path) to handler; 401 when AuthMiddleware rejects
    AuthMiddleware.swift      ✅  // Bearer token check against DaemonAuth.token with constant-time compare
    DaemonAuth.swift          ✅  // lazy static token stored in Keychain under "soli.Cloude.agent/authToken"; generated on first read
  UI/
    macOSDaemonApp.swift      ✅  // @main MenuBarExtra app; starts HTTPServer and warms DaemonAuth.token at init
    ContentView.swift         ✅  // menubar popover contents
  RunnerManager.swift       // map<sessionId, {process, ring buffer, status}>
```

## Agent Rules

- **Prefer sub-agents for information retrieval** - whenever you need to look something up in the codebase, launch an Explore sub-agent instead of reading/grepping yourself. If the questions are independent, launch them in parallel in a single message. Main-thread context is expensive; sub-agent context is cheap.
- **`.claude/` folder requires permission** - Anthropic added a permission gate on Edit/Write/sed for files inside `.claude/`. Since we run headless (no way to accept permission prompts), use workarounds: `cp` to `/tmp`, modify there, `cp` back. Or use `cat` with heredoc redirect. Never use the Edit tool on `.claude/` files.
- **Naming is automatic** - a background agent names conversations.
- **Multi-agent project** - never touch another agent's code. If you see errors from someone else's work, stop and tell the user.
- Full absolute paths starting with `/Users/` render as clickable file pills in the iOS app - always use full paths, never brace notation like {1-6}

## Open questions

- Transcription backend: WhisperKit on-device vs server-side API call?
- Git write operations (commit, branch) from the phone, or keep read-only?
- Supersede behavior: when a new prompt arrives while a run is still active, abort + restart, or queue?
