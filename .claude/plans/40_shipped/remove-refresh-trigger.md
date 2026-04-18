---
title: "Remove RefreshTrigger Mechanism"
description: "Remove the refreshActiveChatView notification and refreshTrigger toggle, now obsolete with per-window state."
created_at: 2026-04-01
tags: ["refactor", "workspace"]
icon: arrow.counterclockwise
build: 122
---


# Remove RefreshTrigger Mechanism {arrow.counterclockwise}
## What Changed

- Removed `refreshTrigger` property from WorkspaceStore and WorkspaceView+State
- Removed `triggerRefresh()` method from WorkspaceStore+UIState
- Removed `refreshActiveChatView` notification from WorkspaceNavigation
- Removed onDismiss callbacks from file preview and git diff sheets in App+Shell
- Simplified chat view identity from `"\(id)-\(refreshTrigger)"` to just `window.id`

## Why

Per-window FileTreeState and GitChangesState made the global refresh mechanism unnecessary. The old pattern forced full view recreation on every sheet dismiss.
