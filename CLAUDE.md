You are most likely running inside Cloude - an iOS app that controls Claude Code remotely. The user is on their phone. A Mac daemon or Linux daemon spawned this CLI process. You are building the system you are running inside of.

The app is currently displayed as **Remote** (bundle ID `soli.Cloude`). The repo is in the middle of a ground-up rewrite on branch `v2`: iOS, macOS daemon, Android, and Linux daemon have all been stripped to barebones and are being rebuilt feature by feature. Most feature code does not exist yet.

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

The iOS app connects to the Mac daemon or Linux daemon over authenticated HTTP on port `8765`. Two options for secure remote access:
- **Cloudflare Tunnel** (preferred): domain routes through Cloudflare's edge to localhost. Automatic TLS, no port forwarding, no VPN. Lighter on iOS battery.
- **Tailscale**: mesh VPN alternative. Works but drains iOS battery more.

Both proxy to `localhost:8765` where the daemon listens. Specific endpoints and tunnel config live in personal memory, not here.

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
- **Inline icon size matches adjacent text** - when an `Image` sits next to a `Text` on the same baseline (pill labels, tab labels, buttons with leading icon), size both with the same `ThemeTokens.Text.*` token. Reserve `ThemeTokens.Icon.*` for standalone icons (icon-only buttons, decorative symbols). Mixing an Icon token next to a Text token creates visual weight mismatch at the baseline.
- **Morphing icons need a fixed frame** - any `Image(systemName:)` that swaps glyphs via `.contentTransition(.symbolEffect(.replace))` (copy → checkmark, play → pause, etc.) must have an explicit `.frame(width:height:)` using a `ThemeTokens.Text.*` or `ThemeTokens.Icon.*` token. SF Symbol glyphs have different intrinsic bounding boxes; without a pinned frame, the surrounding row height jumps mid-animation.

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
        EndpointView.swift           ✅  // dedicated single-endpoint editor destination pushed from WindowsSidebar with labeled Symbol/Host/Port/Auth Token fields, connection test, and delete action
        EndpointsSymbolPicker.swift  ✅  // searchable LazyVGrid of SF Symbols grouped by category; presented from EndpointView's Symbol field
      Logic/
        Endpoint.swift                 ✅  // @Model: id, host, port, name?, symbolName, createdAt, lastCheckTimestamp?, lastCheckReachable?. authKey NOT on the model, lives in Keychain under id.uuidString. name is the optional display label (e.g. "Ahmed's Mac" from the pairing QR).
        EndpointService.swift          ✅  // stateless; GET /ping via HTTPClient (auth resolved from Keychain), writes lastCheckTimestamp + lastCheckReachable. probe(host:port:authKey:retryWindow:) returns EndpointProbeResult (reachable | unauthorized | unreachable | invalid); optional retryWindow polls within a deadline used by Onboarding and EndpointView.
        EndpointProbeResult.swift      ✅  // enum returned by EndpointService.probe: reachable, unauthorized, unreachable, invalid. Drives recovery copy in onboarding and endpoint edit.
        EndpointActions.swift          ✅  // stateless mutations on the Endpoint model: add (seeds a random catalog symbol), create (host/port/name?/symbol/authKey, used by onboarding + manual pairing), update (same params — Onboarding reuses an existing Endpoint with matching host+port instead of double-inserting), remove (deletes Keychain entry + the model), saveAuthKey (no-op if the endpoint was deleted), seedDev (DEBUG-only env-var dev-endpoint seed, called from iOSApp.init)
        EndpointsSymbolCatalog.swift   ✅  // static list of SF Symbol names grouped by category plus a flattened `symbols` pool for random endpoint defaults and EndpointsSymbolPicker
    Sessions/
      UI/
        SessionView.swift            ✅  // owns its top bar and body. Top bar is an HStack: leading hamburger (toggles NavigationSplitView columnVisibility), SessionViewTabs, trailing "+" (WindowActions.addNew). Always renders the tabbed ZStack (chat/files/git); the empty-state decision lives inside ChatView now. Takes a Session + a columnVisibility binding passed down from WindowsView.
        SessionViewTabs.swift        ✅  // 3-tab pill switcher (chat | files | git); rendered inside SessionView's top bar. Bound to SessionView's activeTab.
        SessionEmptyView.swift       ✅  // setup screen shown by ChatView when the session has no messages: hero + endpoint row + folder row + recent sessions list. Owns the folder-sheet @State and presents SessionEmptyViewFolderSheet.
        SessionEmptyViewHero.swift   ✅  // displays the `claude-painter` asset as the empty-state hero.
        SessionEmptyViewEndpointRow.swift ✅  // Capsule-glass row: current endpoint symbol+host with chevron.up.chevron.down. Menu opens endpoint list; selecting one calls SessionActions.setEndpoint then sets the bound folderSheetEndpoint to auto-open the folder sheet.
        SessionEmptyViewFolderRow.swift ✅  // Capsule-glass row showing the truncated leaf of session.path (or "Choose folder"). Tap sets the bound folderSheetEndpoint to the session's endpoint; disabled when no endpoint is set.
        SessionEmptyViewRecentList.swift ✅  // VStack of up to 5 SessionEmptyViewRecentListRow. Filters @Query<Session> (sorted createdAt desc) by excluding the current session and any session open in another Window. Resolves the current window and calls WindowActions.swap on tap.
        SessionEmptyViewRecentListRow.swift ✅  // Capsule-glass pill: session symbol + title + secondary path leaf. Tap fires the provided onTap closure.
        SessionEmptyViewFolderSheet.swift ✅  // sheet presented from SessionEmptyView; wraps FolderPickerView in a NavigationStack, top-leading xmark dismisses, onPick writes path via SessionActions and dismisses.
      Logic/
        Session.swift                ✅  // @Model: id (client-generated, passed to claude as --session-id), endpoint: Endpoint? (SwiftData relationship), path?, lastOpenedAt, title ("Untitled"), symbol ("sparkles"), existsOnServer (flipped true after daemon emits system/init — swaps future spawns from --session-id to --resume), tabRaw (persisted active SessionTab), modelRaw/effortRaw (persisted ChatModel/ChatEffort selection, nil = Auto/Default); @Transient skills?, agents? (fetched on demand). path == nil is the empty-state signal.
        SessionTab.swift             ✅  // enum: chat | files | git; each case has label + SF symbol
        SessionActions.swift         ✅  // stateless mutations on the Session model: add, setEndpoint, setPath, markExistsOnServer, setTab, setModel, setEffort. Owns session-mutation surface so other features don't write Session fields directly.
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
        ChatInputBar.swift                            // text field (hosts inline pills), send button (tap=send, long-press=Menu with model/effort pickers), attachments button; swipe-up gesture drives AudioRecorder and presents AudioInputOverlay
        ChatInputBarSkillPill.swift                   // inline chip for a selected skill (from "/" autocomplete)
        ChatInputBarAgentPill.swift                   // inline chip for a selected agent (from "@" autocomplete)
        ChatInputBarAutocompletePicker.swift          // popover triggered by "/" (skills) or "@" (agents)
        ChatInputBarAttachmentPicker.swift            // picks images from photos/files; opened from the attachments button
      Logic/
        ChatMessage.swift            // sessionId, role, text, tool calls, attachments, state, per-message stats
        ChatToolCall.swift           // tool name, args, result, state (pending/succeeded/failed)
        ChatStreamEvent.swift        // decoded ndjson event: system/init, stream_event, assistant, user, result
        ChatMarkdownParser.swift     // incremental parser: code fences, tool pills, tables - fed stream_event deltas
        ChatService.swift            // streams /sessions/:id/chat; parses ndjson, appends deltas directly onto ChatMessage.text (SwiftData is the single source of truth for live streaming text). start/resume/abort. Reads session.model + session.effort and puts them in the POST body when set.
        ChatModel.swift              ✅  // enum: opus | sonnet | haiku. String raw value is sent to the daemon and passed to claude CLI as --model
        ChatEffort.swift             ✅  // enum: low | medium | high. String raw value is sent to the daemon and passed to claude CLI as --effort
    Audio/
      UI/
        AudioInputOverlay.swift      // covers input bar during recording + transcribing; 7-bar waveform fed by AudioRecorder.level; spinner during AudioService.transcribe
      Logic/
        AudioRecorder.swift          // AVAudioRecorder (16kHz mono PCM WAV), 50ms level polling. stateful device wrapper - the only non-Store/Service type allowed in Logic/
        AudioService.swift           // stateless; POST /audio → String
    Files/
      UI/
        FileTreeView.swift           ✅  // files tab: VSCode-style expanding tree rooted at session.path. Holds a FileTreeStore and presents FilePreviewSheet on tap.
        FileTreeViewRow.swift        ✅  // one row in the tree; tap on a directory toggles expansion (lazy-loads children via FilesService), tap on a file sets store.previewNode. Recursively renders children when expanded.
        FolderPickerView.swift       ✅  // reusable drill-navigable folder list. Takes session, endpoint, path, title, optional onPick. Rows NavigationLink into nested FolderPickerView; when onPick is set, a trailing checkmark toolbar button fires it with the current path. Used by SessionEmptyViewFolderSheet today; FilesView will consume it later.
        FilePreviewSheet.swift       ✅  // single-file preview shell. Owns data load, source/rendered toggle for markup types, and code-wrap toggle; delegates rendering to FilePreviewSheetContent. KNOWN ISSUE: toggling source/rendered feels janky - likely because the sheet re-renders the entire Group on every toggle; investigate a cross-fade or keep both views mounted.
        FilePreviewSheetContent.swift ✅  // dispatcher: switches on FilePreviewContentType and renders the matching FilePreview<Type> view.
        FilePreviewImage.swift       ✅  // zoomable image renderer.
        FilePreviewGIF.swift         ✅  // animated GIF via UIImageView/UIViewRepresentable.
        FilePreviewVideo.swift       ✅  // AVPlayer-backed video; writes data to a temp file, cleans up onDisappear.
        FilePreviewAudio.swift       ✅  // AVPlayer-backed audio with transport controls.
        FilePreviewPDF.swift         ✅  // PDFKit-backed PDF viewer.
        FilePreviewMarkdown.swift    ✅  // MarkdownUI-rendered markdown body.
        FilePreviewJSON.swift        ✅  // pretty tree view of JSON (root).
        FilePreviewJSONRow.swift     ✅  // recursive row for one key/value in the JSON tree.
        FilePreviewCSV.swift         ✅  // scrollable grid; defaultScrollAnchor .topLeading.
        FilePreviewHTML.swift        ✅  // WKWebView-backed HTML renderer.
        FilePreviewXML.swift         ✅  // XML tree, delegates each node to FilePreviewXMLRow.
        FilePreviewXMLRow.swift      ✅  // recursive row for one XML node (attributes + children + text).
        FilePreviewCode.swift        ✅  // HighlightSwift CodeText; language-aware syntax highlighting with optional line wrap.
        FilePreviewBinary.swift     ✅  // fallback placeholder for unrecognized binary files.
      Logic/
        FileNodeDTO.swift            ✅  // Decodable wire structs: FileNodeDTO, FileListingDTO, FileSearchDTO. Mirror daemon responses 1:1
        FilePreviewContentType.swift ✅  // enum of preview content types + extension-based detect(for:) + hasRenderedView/isCode/sourceLanguage helpers.
        FilePreviewXMLNode.swift     ✅  // XML parser: recursive tree built from Foundation's XMLParser.
        FileTreeStore.swift          ✅  // @Observable: children dict, expanded set, loading set, previewNode, rootPath. Shared by FileTreeView and FileTreeViewRow.
        FilesService.swift           ✅  // stateless; list/read (HTTP Range)/search network I/O. URL built from endpoint host+port, session.id goes in path
    Git/
      UI/
        GitView.swift                // git tab: branch header, ahead/behind counts, list of changes; tap for diff
        GitDiffSheet.swift           // unified diff for one file (staged or unstaged); presented as a sheet from GitView
      Logic/
        GitChangeType.swift          // enum: added/modified/deleted/renamed/copied/untracked/ignored/conflicted. Codable (String rawValue) for SwiftData + DTO decoding
        GitChange.swift              // @Model: path, type: GitChangeType, isStaged, additions?, deletions?, status: GitStatus? (inverse)
        GitStatus.swift              // @Model: session: Session? (one per session, upserted), branch, ahead, behind, updatedAt, changes via @Relationship(deleteRule: .cascade)
        GitCommit.swift              // @Model: session: Session?, sha, author, date, subject
        GitStatusDTO.swift           // Decodable wire structs: GitChangeDTO, GitStatusDTO
        GitCommitDTO.swift           // Decodable wire structs: GitCommitDTO, GitLogDTO
        GitActions.swift             // stateless mutations: upsertStatus (one GitStatus per session), replaceLog, clear
        GitService.swift             // stateless; status/diff (raw unified text)/log network I/O
    Windows/
      UI/
        WindowsView.swift            ✅  // top-level screen: NavigationSplitView with WindowsSidebar + detail column (theme background + active SessionView + DebugOverlay). Owns columnVisibility state, passes binding into SessionView.
        WindowsSidebar.swift         ✅  // left sidebar: Settings row (opens SettingsView sheet), Open section (rows activate window, swipe-to-close), Recent section (sessions without a window, tap swaps into focused window, swipe deletes). Closes itself after activate/swap.
        WindowsSidebarRow.swift      ✅  // row primitive used by both sidebar sections: symbol + title, accents when focused.
      Logic/
        Window.swift                 ✅  // @Model: session: Session? (SwiftData relationship), order: Int, isFocused: Bool. One Window per open pill in the switcher.
        WindowActions.swift          ✅  // stateless mutations on the Window model: ensureOne (called from iOSApp.init), activate, addNew, swap, close. addNew/ensureOne insert a matching Session alongside the Window; close deletes only the Window (Session persists for re-opening from WindowsSidebar's Recent section).
    Onboarding/
      UI/
        OnboardingView.swift                     ✅  // root onboarding surface gated from WindowsView when Endpoint count is 0. Owns the OnboardingStore, switches between Install/Pair/Status steps, listens for .deeplinkPair and applies the payload.
        OnboardingViewInstallStep.swift          ✅  // first screen: downloads the latest public DMG to the iPhone, presents a `.sheet(item:)` share sheet for AirDrop, Continue button sets `store.step = .pair`.
        OnboardingViewInstallStepShareSheet.swift ✅  // UIViewControllerRepresentable wrapper around UIActivityViewController for sharing the downloaded DMG via AirDrop.
        OnboardingViewPairStep.swift             ✅  // embeds OnboardingViewScannerSheetPreview inline; "Enter manually" fallback presents OnboardingViewManualSheet. Surfaces camera-permission-denied copy via isPermissionDenied.
        OnboardingViewScannerSheetPreview.swift  ✅  // UIViewControllerRepresentable bridge for the camera preview controller; forwards onCode and onPermissionDenied.
        OnboardingViewScannerSheetController.swift ✅  // UIViewController driving AVCaptureSession, metadata output for QR, debounced single-emit. Checks AVCaptureDevice authorization and calls onPermissionDenied when access is unavailable. Reuses a prepared UINotificationFeedbackGenerator.
        OnboardingViewManualSheet.swift          ✅  // manual fallback form (host/port/token/optional name) → emits OnboardingPairingPayload.
        OnboardingViewStatusStep.swift           ✅  // verify-and-save step: runs EndpointService.probe, shows typed recovery copy for each EndpointProbeResult, calls onFinished(endpoint) and auto-dismisses on .reachable.
      Logic/
        OnboardingInstallService.swift           ✅  // stateless installer download helper. Fetches the latest public GitHub DMG to a temporary file so OnboardingViewInstallStep can present the iOS share sheet for AirDrop.
        OnboardingStep.swift                     ✅  // enum: install | pair | status. Drives OnboardingStore.step.
        OnboardingPairingPayload.swift           ✅  // struct {host, port, token, name?} with init?(url:) parsing cloude://pair?host=&port=&token=&name= URLs.
        OnboardingStore.swift                    ✅  // @Observable MainActor store: step, draft payload, probeResult, isProbing. verifyAndSave hits EndpointService.probe and on .reachable either calls EndpointActions.update on a matching existing Endpoint or EndpointActions.create.
    Settings/
      UI/
        SettingsRow.swift                        ✅  // row primitives: SettingsRow (colored-icon + content) and SettingsToggleRow (row bound to an @AppStorage bool key)
        SettingsViewAccent.swift                 ✅  // row that navigates to SettingsViewAccentPicker
        SettingsViewAccentPicker.swift           ✅  // preset accent list with live AppStorage-backed selection
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
    DeepLinks/
      DeepLinkRouter.swift           ✅  // single entry point for `cloude://` URLs from `iOSApp.onOpenURL`. Hosts: window/new|close|activate, session/endpoint|path|tab, chat/send|abort, pair (parses OnboardingPairingPayload and posts .deeplinkPair), settings, screenshot. Publishes `.deeplinkOpenSettings`, `.deeplinkScreenshot`, `.deeplinkPair` Notification.Names.
    Networking/
      HTTPClient.swift               ✅  // stateless GET/download; every request takes an Endpoint and the client builds the URL, resolves the bearer token from SecureStorage via endpoint.id, and returns (Data, HTTPURLResponse)? (nil on transport error). No caller ever passes authKey.
      StreamingClient.swift          // ndjson reader with resume-on-disconnect via after_seq
    Storage/
      SecureStorage.swift            ✅  // Keychain wrapper: get/set/delete keyed by account string (scoped to service "soli.Cloude.environments"); used for per-endpoint auth tokens
      StorageKey.swift               ✅  // shared @AppStorage key constants (fontSizeStep, debugOverlayEnabled, wrapCodeLines, appTheme, appAccent)
    Notifications/
      NotificationService.swift      // local notification when a run completes in background
    UI/
      IconPillButton.swift           ✅  // shared capsule pill chrome (symbol + action) used by the SessionView top bar (hamburger + add) and other icon buttons
    Theme/
      AppAccent.swift                ✅  // preset app accent options; powers user-selectable primary accent color
      Theme.swift                    ✅  // enum Theme (presets) + nested Palette struct (background/surface/elevated/colorScheme)
      ThemeColor.swift               ✅  // semantic color aliases (blue/cyan/success/danger/etc.) + Color(hex:) initializer
      ThemeTokens.swift              ✅  // design tokens: Text/Icon/Spacing/Radius/Size/Scale/Stroke/Duration/Delay/Opacity
      ThemeEnvironment.swift         ✅  // EnvironmentValues.theme + appAccent + .fontStep + .appFont(size:weight:design:) + .themedNavChrome() modifiers
  iOSApp.swift                       ✅  // @main App; constructs the SwiftData ModelContainer (Endpoint/Session/Window), calls EndpointActions.seedDev + WindowActions.ensureOne at init, renders WindowsView with .modelContainer injected and theme/accent/fontStep AppStorage
```

## macOS daemon

Regular macOS app exposing an HTTP listener. Handlers map 1:1 to routes. Runner manager holds the only piece of server-side state.

```
src/
  Handlers/
    ChatHandler.swift         ✅  // delegates start/resume/abort to RunnerManager.shared
      POST /sessions/:id/chat         start()      // body {path, prompt, images?, existsOnServer}. Spawns `claude -p --session-id <id>` (or `--resume <id>` when existsOnServer=true), pipes prompt+images to stdin, streams ndjson. If a turn is already running for this session, aborts it first.
      GET  /sessions/:id/chat/resume  resume()     // ?after_seq=N. Replays ring events > N then tails live. 404 if no runner exists.
      POST /sessions/:id/chat/abort   abort()      // SIGINT the running claude process; emits a final `aborted` event on the stream
    FilesHandler.swift        ✅
      GET  /sessions/:id/files?path=…                       list()    // directory listing → {path, entries:[{name,path,isDirectory,size?,modifiedAt?,mimeType?}]}
      GET  /sessions/:id/files/read?path=…                  read()    // raw bytes, detected Content-Type, honors Range → 206 Partial Content
      GET  /sessions/:id/files/search?path=…&query=…        search()  // native FileManager enumeration, depth≤5, skips .git/node_modules, caps 100 hits → {entries:[…]}
    GitHandler.swift         ✅
      GET  /sessions/:id/git/status?path=…                  status()  // {branch, ahead, behind, changes:[{path,type,isStaged,additions?,deletions?}]}. Shells out to git; private runText() helper inside the handler
      GET  /sessions/:id/git/diff?path=…&file=…&staged=…    diff()    // raw unified diff, text/plain
      GET  /sessions/:id/git/log?path=…&count=…             log()     // {commits:[{sha,subject,author,date}]}
    SessionHandler.swift     ✅
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
    HTTPRequest.swift         ✅  // parsed request: method, path, query (parsed at request-parse time), headers (lowercased keys), body
    HTTPResponse.swift        ✅  // status + Body enum (.buffered(Data) | .streamed((NWConnection) -> Void)) + content-type; .json / .text / .stream factory helpers
    HTTPServer.swift          ✅  // NWListener on port 8765; reads headers+body (1MB cap), routes through Router; switches on response.body to pick buffered send vs header-then-streamer
  Routing/
    Router.swift              ✅  // dispatches (method, path) to handler; 401 when AuthMiddleware rejects
    AuthMiddleware.swift      ✅  // Bearer token check against DaemonAuth.token with constant-time compare
    RouteMatcher.swift        ✅  // splits rawPath into (path, query) and matches path against `/sessions/:id/…` patterns, returning captured params
    DaemonAuth.swift          ✅  // lazy static token stored in Keychain under "soli.Cloude.agent/authToken"; generated on first read
  UI/
    macOSDaemonApp.swift      ✅  // @main MenuBarExtra app; starts HTTPServer and warms DaemonAuth.token at init
    ContentView.swift         ✅  // menubar popover: computer name header, HOST row (local IP with copy), AUTH TOKEN row (with copy), inline pairing QR of the cloude://pair URL. Quit button at the bottom. Delegates each labelled copy row to ContentViewCopyRow.
    ContentViewCopyRow.swift  ✅  // reusable labelled copy-row pill used by ContentView (HOST + AUTH TOKEN): monospaced value + doc.on.doc button that flips to checkmark while isCopied is true.
    DaemonHost.swift          ✅  // static helpers: computerName (Host.current().localizedName) and localIPv4 (getifaddrs, skips loopback/down, prefers en* interfaces, falls back to any non-loopback IPv4).
    DaemonPairingURL.swift    ✅  // builds the cloude://pair?host=&port=&token=&name= URL consumed by iOS OnboardingPairingPayload. Returns nil when no local IPv4 is available.
    DaemonQR.swift            ✅  // CoreImage QR generator (CIFilter.qrCodeGenerator) → NSImage at requested pixel size. No third-party dependency.
  RunnerManager.swift       ✅  // serial-queue actor around map<sessionId, Runner>. start spawns/replaces, resume attaches a subscriber, abort SIGINTs.
  Runner.swift              ✅  // one claude child process + ring buffer + NWConnection subscribers. Prunes dead subscribers via stateUpdateHandler. Batches replay into a single send on subscribe.
  ImageDropbox.swift        ✅  // persists incoming base64 images to a per-call FileManager.default.temporaryDirectory subfolder and rewrites the prompt to reference absolute paths
```

## Linux daemon

Node.js HTTP daemon matching the macOS route surface and NDJSON chat stream envelope. Linux keeps its auth token in a file at `~/.cloude-agent/auth-token` or `$CLOUDE_DATA/auth-token`.

```
daemons/linux/
  index.js                 ✅  // boots the HTTPServer, warms DaemonAuth, reads CLOUDE_HOST/CLOUDE_PORT/CLOUDE_DATA
  install.sh               ✅  // installs `cloude-agent.service` under systemd and prints local ping checks
  README.md                ✅  // setup, auth, and firewall guidance for remote Linux hosts
  src/
    Handlers/
      ChatHandler.js         ✅  // POST /sessions/:id/chat, GET /sessions/:id/chat/resume, POST /sessions/:id/chat/abort; same request/response shapes as macOS
      FilesHandler.js        ✅  // GET /sessions/:id/files, /read, /search; directory listing + range reads + bounded search
      GitHandler.js          ✅  // GET /sessions/:id/git/status, /diff, /log; mirrors macOS response shapes including diff truncation header
      PingHandler.js         ✅  // GET /ping, returns {"ok": true, "serverAt": ...}
      SessionHandler.js      ✅  // POST /sessions/:id/title; same title+symbol generation contract as macOS
      SessionJSONLReplay.js  ✅  // replays the last turn from ~/.claude/projects/.../<session>.jsonl when no live runner exists
    Networking/
      HTTPRequest.js         ✅  // normalized method/path/query/headers/body wrapper around Node's request object
      HTTPResponse.js        ✅  // buffered or streamed HTTP responses with shared content-type/header handling
      HTTPServer.js          ✅  // Node http server on port 8765 with a 1MB request cap and streamed NDJSON support
    Routing/
      AuthMiddleware.js      ✅  // Bearer token check against DaemonAuth with constant-time comparison
      DaemonAuth.js          ✅  // lazy file-backed token loader/generator
      RouteMatcher.js        ✅  // splits raw URLs and matches `/sessions/:id/...` patterns
      Router.js              ✅  // dispatches authenticated requests to handlers
    Runtime/
      ClaudeRuntime.js       ✅  // resolves claude from PATH plus Linux user-install locations and builds the spawn environment
    ImageDropbox.js        ✅  // writes uploaded images to a temp folder and rewrites the prompt to reference those files
    Runner.js              ✅  // one claude child process + ring buffer + live HTTP subscribers
    RunnerManager.js       ✅  // sessionId → Runner map; aborts superseded runs and attaches resume subscribers
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
