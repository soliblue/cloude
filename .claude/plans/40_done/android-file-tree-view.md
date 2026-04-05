# Android File Tree View {folder.fill}
<!-- priority: 12 -->
<!-- tags: android, files, ux -->

> Replace navigate-into-folder file browser with inline tree view.

## Desired Outcome
VS Code-style tree view with expandable folders, depth-based indentation, chevron indicators, and per-folder loading states. Users can see the full directory structure without navigating away.

## iOS Reference Architecture

### Components
- `FileTreeView.swift` - main tree rendering with expand/collapse
- `FileTreeView+Row.swift` - row component with depth indentation
- `FileTreeNode.swift` - data model for tree nodes
- `FileTreeState.swift` - state management with expandedPaths set

### Android implementation notes
- Replace current `FileBrowserScreen` list-based navigation
- Use `LazyColumn` with indentation based on depth level
- Track expanded paths in a `Set<String>` state
- Chevron icon rotates on expand/collapse
- Load folder contents lazily on first expand
- Show loading indicator per-folder while fetching

**Files (iOS reference):** FileTreeView.swift, FileTreeView+Row.swift, FileTreeNode.swift, FileTreeState.swift
