# Window Edit Sheet Overhaul

## Changes (Build 39-40)

- Content pinned to top with ScrollView (was vertically centered)
- Removed "Edit Chat" navigation title
- Removed redundant checkmark button (changes auto-save)
- Moved +, branch, effort, refresh, delete buttons to toolbar (top right) with dividers
- Thinking effort picker replaced with brain icon menu in toolbar
- Removed "Recent" section label
- Symbol picker button: rounded rect matching text field height (was circle)
- Removed `.presentationBackground(.ultraThinMaterial)` from sheet
- Full flat conversation list replaces limited 5-item recent + "See All"
- Deleted `WindowConversationPicker` entirely (integrated into edit sheet)
- Each conversation row shows project name + message count
- Removed bottom + button from empty state (already in toolbar)
- Chained command pills use light `›` instead of chain link icon
- Toolbar buttons get horizontal padding (8pt) for breathing room
