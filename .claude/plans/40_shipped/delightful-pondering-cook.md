# Refactor: Window Switcher → Sidebar

## Context

Today the app's window management lives in a bottom pill strip (`WindowsViewSwitcher`) with SettingsPill, one pill per open Window, and an add pill. It only shows open windows and gives no surface for jumping back into closed sessions (you have to start empty and use `SessionEmptyViewRecentList`).

We want a single place that lists everything — settings, open windows, closed sessions — and frees up the bottom of the screen (chat input). Replace the bottom switcher with a left sidebar driven by `NavigationSplitView`, toggled from a hamburger in the existing top tab row.

## Decisions (from clarifying Qs)

1. **Presentation**: `NavigationSplitView` (sidebar column + detail). On iPhone this behaves as a drawer.
2. **Tapping a closed session**: swaps the focused window's session via `WindowActions.swap(_:to:)`. Does not grow window count.
3. **Hamburger placement**: leading in the same row as `SessionViewTabs`.
4. **Add ("+") button**: trailing in that same row.

## Target shape

```
WindowsView
 └── NavigationSplitView(columnVisibility)
      ├── sidebar:   WindowsSidebar
      │               ├── Settings row    → presents SettingsView (existing sheet)
      │               ├── Section "Open"     → @Query windows, rows activate / swipe-to-close
      │               ├── Divider
      │               └── Section "Recent"   → @Query sessions NOT in any window, tap swaps into focused window
      └── detail:    SessionView(session)    (unchanged body; new top bar)

SessionView top bar (leading → trailing):
 [hamburger]  SessionViewTabs  [add]
```

## Files

### New
- `clients/ios/src/Features/Windows/UI/WindowsSidebar.swift` — `List` with three sections. Owns `@Query(sort: \Window.order)` and `@Query(sort: \Session.lastOpenedAt, order: .reverse)`. Filters "remaining" by excluding `Set(windows.compactMap { $0.session?.id })` (pattern already used in `SessionEmptyViewRecentList.swift:23-28`). Holds `@State isSettingsPresented` and presents `SettingsView` as a sheet from the settings row. All mutations go through `WindowActions` / `SessionActions` — no direct context writes.

### Modified
- `clients/ios/src/Features/Windows/UI/WindowsView.swift` — replace the `.safeAreaInset(.bottom) { WindowsViewSwitcher() }` with `NavigationSplitView(columnVisibility: $columnVisibility) { WindowsSidebar(columnVisibility: $columnVisibility) } detail: { SessionView(...) }`. Keep `DebugOverlay` + `.modifier(ThemedNavChrome())`. Store `@State var columnVisibility: NavigationSplitViewVisibility = .detailOnly` so iPhone opens with sidebar closed. Tapping a row in the sidebar (activate / swap) sets `columnVisibility = .detailOnly` to auto-close.
- `clients/ios/src/Features/Sessions/UI/SessionView.swift` — the existing `.safeAreaInset(.top)` body becomes an `HStack(spacing: ThemeTokens.Spacing.s)` with:
  - leading `Button { columnVisibility = .all } label: Image("line.3.horizontal")` styled via `IconPillButton` (glass capsule, `ThemeTokens.Text.m`)
  - middle `SessionViewTabs` (unchanged)
  - trailing add button — reuses `IconPillButton` symbol `"plus"`, calls `WindowActions.addNew(...)` (same logic as today's `WindowsViewSwitcherAddPill`).

  Pass the `columnVisibility` binding down from `WindowsView` through a new param on `SessionView`.
- `clients/ios/src/Core/UI/IconPillButton.swift` — no code change, but confirm it already provides the shared capsule chrome (gear/plus/hamburger all share it).

### Deleted
- `clients/ios/src/Features/Windows/UI/WindowsViewSwitcher.swift`
- `clients/ios/src/Features/Windows/UI/WindowsViewSwitcherPill.swift`
- `clients/ios/src/Features/Windows/UI/WindowsViewSwitcherAddPill.swift`
- `clients/ios/src/Features/Settings/UI/SettingsPill.swift` (sidebar row now opens settings)

### Untouched / reused
- `WindowActions.swift` — `activate`, `addNew`, `close`, `swap` all already exist. No new mutations needed.
- `SettingsView.swift` — kept as-is; still presented as a sheet.
- `SessionViewTabs.swift` — unchanged.
- `SessionEmptyView.swift` / `SessionEmptyViewRecentList.swift` — stay; orthogonal to this change.

## Sidebar rows

- **Settings row**: `SettingsRow` with gear icon + "Settings"; tap → `isSettingsPresented = true`.
- **Open windows section**: `ForEach(windows)` — row shows `session.symbol` + `session.title`, highlights when `window.isFocused`. Tap → `WindowActions.activate(window, among: windows)` then close sidebar. `.swipeActions(edge: .trailing) { Button(role: .destructive) { WindowActions.close(window, among: windows, in: context) } }` — close gesture is explicit, replaces long-press.
- **Divider**: native `Section` boundary is enough (List gives grouped look).
- **Recent sessions section**: `ForEach(sessionsNotOpen)` — row shows symbol + title + relative `lastOpenedAt`. Tap → `WindowActions.swap(focusedWindow, to: session)` then close sidebar. `.swipeActions { Button(role: .destructive) { context.delete(session) } }` — permanent delete, no Window exists so no `close()` needed.

## Structure doc

Update `CLAUDE.md` iOS tree:
- Remove `WindowsViewSwitcher*.swift` lines and `SettingsPill.swift` line.
- Add `WindowsSidebar.swift` under `Features/Windows/UI/`.
- Update `WindowsView.swift` comment to describe `NavigationSplitView` instead of `safeAreaInset`.
- Update `SessionView.swift` comment to note the top bar now hosts hamburger + tabs + add.

## Verification

1. `swift-format -i` every edited/new `.swift` file.
2. Build iOS target in Xcode (CLAUDE.md's `fileSystemSynchronizedGroups` means no project file edits — new files pick up automatically).
3. Manual:
   - Launch → bottom pill strip gone; chat input sits at bottom edge.
   - Tap hamburger → sidebar slides in with Settings, Open (≥1 row for current window), Recent (whatever closed sessions exist).
   - Tap Settings row → existing settings sheet.
   - Tap another open window → sidebar closes, focused session swaps.
   - Swipe-close on an open window → window disappears, neighbor takes focus (existing `WindowActions.close` behavior).
   - Tap a recent session → sidebar closes, current window's session swaps to that one (`WindowActions.swap`); the previous session, if empty, is cleaned up by `deleteIfEmpty()` inside `swap`.
   - Tap "+" in top bar → new window + session spawned, becomes focused.
   - Rotate / dynamic type / font size step still affect tab row.
