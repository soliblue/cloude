# Git Refresh on Tab Switch & History Auto-Send {arrow.triangle.2.circlepath}
<!-- priority: 8 -->
<!-- tags: ui, git -->
> Refresh git status when switching windows and auto-send when selecting a history suggestion.

## Changes

- `WorkspaceStore+Lifecycle`: trigger `gitStatus` on active window change so the git tab is fresh
- `WorkspaceView+InputBar+Content`: selecting a history suggestion now dismisses keyboard and sends immediately
- `WorkspaceView`: pass connection to `handleActiveWindowChange`
