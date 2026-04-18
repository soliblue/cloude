# Preserve scroll position when switching tabs {scroll}
<!-- priority: 10 -->
<!-- tags: ui, tabs -->

> Keep files and git tab scroll positions stable across tab switches.

## Problem
Conditional rendering (`if window.tab == .files`) destroyed and recreated views on each tab switch, losing scroll position.

## Solution
All three tabs (chat, files, git) now use opacity/hitTesting toggling in `WorkspaceView+Windows.swift` so views stay mounted. External `@ObservedObject` state on `WindowManager` (`FileTreeState`, `GitChangesState`) holds data across renders.

Since views mount before the connection is ready, `FileTreeView` takes an `isVisible` parameter that triggers `loadRootIfNeeded()` on first tab switch. The git tab loads via the existing window-focus git status handler.

## Files
- `WorkspaceView+Windows.swift` - opacity approach for all tabs
- `FileTreeView.swift` - `isVisible` param, simplified onChange watchers
- `GitChangesView.swift` - simplified onChange to single `resolvedRepoPath` watcher
