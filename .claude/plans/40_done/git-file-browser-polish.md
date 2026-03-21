# Git & File Browser Polish {paintbrush}
<!-- priority: 10 -->
<!-- tags: ui, git, file-preview -->
<!-- build: 86 -->

> Shrunk git tab fonts/badges and added rich file type icons to file browser.

Two UI tweaks to the window header tabs.

## Git Tab
- Make fonts smaller (file name, path, status badge)
- Shrink the M/A/D status badges

## File Browser Tab
- Use `fileIconName()` and `fileIconColor()` from `FileIconUtilities.swift` instead of generic mime-based icons
- Already have rich icon mapping for swift, md, json, py, etc.

## Files
- `GitChangesView+Components.swift` - shrink fonts and badge
- `FileBrowserView+Components.swift` - use fileIconName/fileIconColor
- `FileEntry+Display.swift` - update icon to use fileIconName
