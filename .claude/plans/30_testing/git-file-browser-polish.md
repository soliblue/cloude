# Git & File Browser Polish
<!-- build: 86 -->

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
