---
title: "File Browser Tree View"
description: "VS Code-style expandable tree view for the main files tab, replacing navigate-into-folder behavior."
created_at: 2026-04-01
tags: ["ui", "files"]
icon: folder.badge.gearshape
build: 122
---


# File Browser Tree View
## Behavior

- Root shows contents of the window's working directory (no path bar)
- Folders have a chevron disclosure indicator (right when collapsed, down when expanded)
- Tapping a folder toggles expand/collapse inline with animated insertion/removal
- Children render indented under their parent (depth-based leading padding)
- Tapping a file opens the existing preview sheet
- Each folder expansion triggers a `listDirectory` call; results are cached
- Collapsing a folder hides children but keeps cache (re-expanding is instant)
- Loading state: show a small spinner next to the folder while its listing loads

## Scope

- New `FileTreeView` for the main files tab in `Features/Files/Views/`
- Existing `FileBrowserView` stays untouched (used by file preview sheets)
- Swap `FileBrowserView` for `FileTreeView` in `WorkspaceView+Windows.swift`
- Remove nothing from `FileBrowserView`

## Files

- `Features/Files/Views/FileTreeView.swift` - main tree view (state, event handling, root list)
- `Features/Files/Views/FileTreeView+Row.swift` - row rendering with depth indentation
- `WorkspaceView+Windows.swift` - swap `FileBrowserView` -> `FileTreeView`
