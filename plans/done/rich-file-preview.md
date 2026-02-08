# Rich File Preview
<!-- priority: 10 -->
<!-- tags: files, ui -->
<!-- build: 56 -->

When opening a file from chat (via path pill tap), show a full file viewer with contextual actions instead of a bare preview.

## Problem

Currently tapping a file path in chat opens a basic preview — just the file content. No navigation, no actions, no context. The file browser already has useful navigation (breadcrumb path, folder browsing), but file previews opened from chat don't get any of that.

## Goals
- Unified file viewing experience whether you open from chat or file browser
- Tappable breadcrumb path for navigating parent directories
- Contextual action toolbar based on what you're viewing
- Feels like a lightweight IDE, not a dumb text dump

## Features

### Universal (all files)
- **Breadcrumb path bar** — each path component is tappable, navigates to that folder in the file browser
- **Filename + extension** prominently displayed
- **Share/copy** button

### Code files (.swift, .py, .js, etc.)
- **Git diff** button — show unstaged changes for this file (inline diff view)
- **Line numbers**
- **Syntax highlighting** (already have this?)
- **"Open in Xcode"** or equivalent (via `cloude open` with file URL?)

### Images
- Pinch to zoom
- Dimensions / file size info

### Markdown
- Rendered preview (already have MarkdownText)

## Approach
- Create a shared `FileViewerHeader` component used by both file browser and chat file preview
- Breadcrumb navigation reuses the file browser's folder navigation
- Action toolbar is contextual — different buttons based on file extension
- Git diff could call `git diff <path>` and render inline with add/remove coloring

## Files
- `Cloude/UI/FilePreviewView.swift` — enhance with header, toolbar, breadcrumb
- `Cloude/UI/FileBrowserView.swift` — extract shared navigation components
- New: `Cloude/UI/FileViewerHeader.swift` or similar shared component
- `Cloude/Services/ConnectionManager.swift` — may need new command for git diff of specific file

## Open Questions
- How deep do we go on git integration? Just diff, or also blame, log?
- Should the breadcrumb replace the current nav title or sit below it?
- Do we want an "Open in chat" action that sends the file path to the input bar for Claude to read?
- Performance considerations for large files with syntax highlighting + diff
