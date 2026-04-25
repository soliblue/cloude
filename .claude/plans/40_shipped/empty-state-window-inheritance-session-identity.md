# Empty-state redesign + new-window inheritance + random session identity

## Context

Three related gaps in the new-session / empty-window UX:

1. `WindowActions.spawn` always creates a blank `Session()` with no endpoint or path. Users almost always want to keep working on the environment and folder they already have open.
2. `SessionView` branches on `endpoint == nil || path.isEmpty`: once both are set, the switch is irreversible from the UI. There is no way to swap envs, no way to jump into a recent session, and no hero/empty moment inside a configured-but-empty chat.
3. Fresh sessions default to `title: "Untitled"`, `symbol: "sparkles"` (`Session.swift:6-7`). Every pill in the switcher looks identical.

Redesign mirrors the empty-state pattern from `cloude-main` (hero illustration, env/folder rows, recent sessions) but stays inside the existing SwiftData + feature-folder architecture. Decisions locked in with the user:

- Hero: use the `claude-painter` illustration asset for the empty-state hero.
- Recent list: all sessions except those currently owned by another `Window`, sorted by `Session.lastOpenedAt` desc, take 5.
- Tap recent → delete current blank session if it has zero messages, reassign `window.session` to the tapped one.
- New window inherits both endpoint and path from the currently focused window.

## Shape

```
WindowsView
  └── SessionView(window, session)          // always renders tabs + body
        ├── SessionViewTabs
        └── ZStack
              ├── ChatView(window, session)
              │     ├── (if messages empty) SessionEmptyView(window, session)
              │     │     ├── SessionEmptyViewHero           (new)
              │     │     ├── SessionEmptyViewEndpointRow    (new)
              │     │     ├── SessionEmptyViewFolderRow      (new)
              │     │     └── SessionEmptyViewRecentList     (new)
              │     │           └── SessionEmptyViewRecentListRow (new)
              │     └── (else) ChatViewMessageList
              │     ChatInputBar(enabled: endpoint && path != nil)
              ├── FileTreeView
              └── Git placeholder

WindowsViewSwitcherAddPill
  └── WindowActions.addNew(...)              // inherits endpoint+path from focused
        └── SessionActions.add(endpoint:, path:)
              └── Session(title: SessionRandom.name(), symbol: SessionRandom.symbol(), ...)
```

## Files to create

### `clients/ios/src/Features/Sessions/Logic/SessionRandom.swift`
Two static arrays + `name()` / `symbol()` helpers. Verbatim port of `cloude-main`'s `Cloude/Cloude/Features/Conversation/Models/Conversation.swift` `randomNames` (48 words) and `randomSymbols` (37 SF Symbols). Implementer must copy the arrays from the `cloude-main` worktree at `/Users/soli/Desktop/CODING/cloude-main`.

```swift
enum SessionRandom {
    static let names: [String] = [ /* copy from cloude-main */ ]
    static let symbols: [String] = [ /* copy from cloude-main */ ]
    static func name() -> String { names.randomElement() ?? "Chat" }
    static func symbol() -> String { symbols.randomElement() ?? "sparkles" }
}
```

### `clients/ios/src/Features/Sessions/UI/SessionEmptyViewHero.swift`
Static empty-state hero using `Image("claude-painter")`.

### `clients/ios/src/Features/Sessions/UI/SessionEmptyViewEndpointRow.swift`
Row showing the session's endpoint (symbol + host). `Menu` overlay lists all `Endpoint`s from `@Query(sort: \Endpoint.createdAt)`. Selecting one (different or same) calls `SessionActions.setEndpoint` and sets `@State var pickerEndpoint = endpoint` which presents `SessionEmptyViewFolderSheet` (reuses the existing sheet). If `session.endpoint == nil`, the row reads "Choose environment".

### `clients/ios/src/Features/Sessions/UI/SessionEmptyViewFolderRow.swift`
Row showing the leaf of `session.path` (or "Choose folder"). Tap sets `@State var pickerEndpoint = session.endpoint` to present `SessionEmptyViewFolderSheet`. Disabled/hidden if `session.endpoint == nil`.

### `clients/ios/src/Features/Sessions/UI/SessionEmptyViewRecentList.swift`
```swift
struct SessionEmptyViewRecentList: View {
    let window: Window
    let session: Session
    @Query(sort: \Session.lastOpenedAt, order: .reverse) private var all: [Session]
    @Query private var windows: [Window]
    var body: some View {
        let openIds = Set(windows.compactMap { $0.session?.id })
        let recents = all.filter { !openIds.contains($0.id) }.prefix(5)
        VStack(spacing: ThemeTokens.Spacing.s) {
            ForEach(Array(recents)) { target in
                SessionEmptyViewRecentListRow(window: window, current: session, target: target)
            }
        }
    }
}
```

### `clients/ios/src/Features/Sessions/UI/SessionEmptyViewRecentListRow.swift`
Capsule pill matching `WindowsViewSwitcherPill`'s chrome: `Image(systemName: target.symbol)` + `Text(target.title)` + secondary `Text` of the path leaf. Tap → `WindowActions.swap(window, from: current, to: target, context:)`.

## Files to modify

### `clients/ios/src/Features/Sessions/Logic/Session.swift`
Keep the default inits (`title: "Untitled"`, `symbol: "sparkles"`) intact — they preserve SwiftData decoding for existing records. `SessionActions.add` overrides them for new inserts. No schema change.

Use existing `lastOpenedAt` as the "recent" sort key (it is initialised to `.now` and never updated today; that is acceptable for this slice). No new timestamp field.

### `clients/ios/src/Features/Sessions/Logic/SessionActions.swift`
Change `add` signature and body:
```swift
@MainActor
static func add(
    into context: ModelContext,
    endpoint: Endpoint? = nil,
    path: String? = nil
) -> Session {
    let session = Session(
        endpoint: endpoint,
        path: path,
        title: SessionRandom.name(),
        symbol: SessionRandom.symbol()
    )
    context.insert(session)
    return session
}
```

Add a new deletion helper (this keeps cross-feature rules intact — only `SessionActions` deletes `Session`):
```swift
@MainActor
static func deleteIfEmpty(_ session: Session, context: ModelContext) {
    let sid = session.id
    let descriptor = FetchDescriptor<ChatMessage>(
        predicate: #Predicate<ChatMessage> { $0.sessionId == sid }
    )
    let count = (try? context.fetchCount(descriptor)) ?? 0
    if count == 0 { context.delete(session) }
}
```

### `clients/ios/src/Features/Windows/Logic/WindowActions.swift`
Change `addNew` to inherit endpoint+path from whichever window is currently focused:
```swift
@MainActor
static func addNew(into context: ModelContext, after windows: [Window]) {
    let nextOrder = (windows.map(\.order).max() ?? -1) + 1
    let focused = windows.first(where: \.isFocused)?.session
    windows.forEach { $0.isFocused = false }
    let session = SessionActions.add(
        into: context,
        endpoint: focused?.endpoint,
        path: focused?.path
    )
    context.insert(Window(session: session, order: nextOrder, isFocused: true))
}
```

`spawn` (used by `ensureOne`) stays unchanged — a fresh install still gets a blank session, and the empty view picks up from there.

Add:
```swift
@MainActor
static func swap(_ window: Window, from current: Session, to target: Session, context: ModelContext) {
    window.session = target
    target.lastOpenedAt = .now
    SessionActions.deleteIfEmpty(current, context: context)
}
```

### `clients/ios/src/Features/Sessions/UI/SessionView.swift`
Drop the outer branch. Always render the tabbed layout. Take `window: Window` as a new property so `ChatView` can forward it. Body becomes just the existing `ZStack { ChatView(window:session:) ; FileTreeView ; git placeholder }.safeAreaInset(...)`. File/git tabs keep whatever they already show today, untouched.

### `clients/ios/src/Features/Chat/UI/ChatView.swift`
Take `window: Window`. Add a session-scoped count query to decide empty:
```swift
@Query private var messages: [ChatMessage]
init(window: Window, session: Session) {
    self.window = window
    self.session = session
    let sid = session.id
    _messages = Query(filter: #Predicate<ChatMessage> { $0.sessionId == sid })
}
```
Layout:
```swift
ZStack(alignment: .bottom) {
    if messages.isEmpty {
        SessionEmptyView(window: window, session: session)
    } else {
        ChatViewMessageList(session: session, bottomInset: barHeight)
    }
    ChatInputBar(enabled: session.endpoint != nil && !(session.path ?? "").isEmpty,
                 onSend: { prompt, images in … })
}
```
`resumeIfStuck` stays.

### `clients/ios/src/Features/Chat/UI/ChatInputBar.swift`
Add `var enabled: Bool = true`. The send `Button`'s `.disabled` becomes `!canSend || !enabled`; the arrow colour uses `enabled && canSend` for the accent path.

### `clients/ios/src/Features/Windows/UI/WindowsView.swift`
Pass the window through: `SessionView(window: window, session: session)`.

### `clients/ios/src/Features/Sessions/UI/SessionEmptyView.swift`
Rewrite to the new layout:
```swift
struct SessionEmptyView: View {
    let window: Window
    let session: Session
    var body: some View {
        VStack(spacing: ThemeTokens.Spacing.l) {
            Spacer()
            SessionEmptyViewHero()
                .frame(maxWidth: .infinity)
                .frame(height: ThemeTokens.Size.xxl)
            VStack(spacing: ThemeTokens.Spacing.s) {
                SessionEmptyViewEndpointRow(session: session)
                SessionEmptyViewFolderRow(session: session)
            }
            SessionEmptyViewRecentList(window: window, session: session)
            Spacer()
        }
        .padding(ThemeTokens.Spacing.m)
    }
}
```
(`ThemeTokens.Size` maxes out at `xxl = 200`; no `xxxl` exists, use `xxl`.)

### `clients/ios/src/Features/Sessions/UI/SessionEmptyViewFolderSheet.swift`
No code change — its `onPick` already calls `SessionActions.setEndpoint` + `setPath`, which is exactly what both new rows need.

### `CLAUDE.md`
Add ticks for the five new UI files and the new Logic file under `Features/Sessions/`. Update the one-liners for `SessionActions.swift`, `WindowActions.swift`, `SessionView.swift`, `ChatView.swift`, `ChatInputBar.swift`, and `SessionEmptyView.swift` to reflect the new behavior (random names/symbols, inheritance on new window, message-count-driven empty state, swap flow).

## Reuse (no change)

- `SessionEmptyViewFolderSheet.swift` — reused verbatim by both new rows.
- `FolderPickerView` — consumed by the sheet.
- `Assets.xcassets/Claude on Clouds/claude-painter.imageset` — consumed by `SessionEmptyViewHero`.
- `IconPillButton`, `ThemeTokens`, `ThemeEnvironment` — chrome.

## Verification

After editing any `.swift` file, run `swift-format -i` on the touched files (see `.swift-format` at repo root).

1. **Random identity.** Clean install → add two windows via "+". Each pill shows a distinct symbol and title.
2. **Inheritance.** Configure one window with endpoint + path, tap "+". The new `SessionEmptyView` shows the hero + the same endpoint/path prefilled in the rows; no sheet auto-opens, recent list hides the open session.
3. **Endpoint-change auto-opens folder picker.** On an empty session, tap the endpoint row, pick a different env — folder sheet opens immediately, rooted at that endpoint.
4. **Empty state is messages-driven.** With endpoint + path set and zero messages → empty view is visible. Send a message → empty view disappears, `ChatViewMessageList` takes over. Input bar stays visible and enabled throughout.
5. **Disabled input.** On a session where `endpoint == nil` or `path == nil`, the input bar's send button is disabled and greyed.
6. **Recent list.** With 3 existing sessions and 1 of them open in another window, the recent list shows 2 rows, `lastOpenedAt` desc, the already-open session absent.
7. **Swap.** From a blank inherited session, tap a recent row. The blank session is deleted (SwiftData count of `Session` drops by 1), the window pill updates to the tapped session's symbol/title, chat content is the tapped session's messages.
8. **Non-empty is preserved on swap.** If the "current" session actually had messages (unusual — would mean the user was already in empty state of a non-empty session, e.g. theoretical race), it is not deleted. Confirm by fetching and checking it still exists.
9. **Close + focus.** Orthogonal regression: closing the focused window still moves focus to `n-1`.
