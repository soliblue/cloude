# Remove RefreshTrigger Mechanism {arrow.counterclockwise}
<!-- priority: 10 -->
<!-- tags: refactor, workspace -->
> Remove the refreshActiveChatView notification and refreshTrigger toggle, now obsolete with per-window state.

## What Changed

- Removed `refreshTrigger` property from WorkspaceStore and WorkspaceView+State
- Removed `triggerRefresh()` method from WorkspaceStore+UIState
- Removed `refreshActiveChatView` notification from WorkspaceNavigation
- Removed onDismiss callbacks from file preview and git diff sheets in App+Shell
- Simplified chat view identity from `"\(id)-\(refreshTrigger)"` to just `window.id`

## Why

Per-window FileTreeState and GitChangesState made the global refresh mechanism unnecessary. The old pattern forced full view recreation on every sheet dismiss.
