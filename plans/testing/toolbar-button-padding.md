# Toolbar Button Padding

Added `.padding(.horizontal, 8)` to the plans/memory toolbar button group in `CloudeApp.swift` to match the existing pattern in `WindowEditSheet.swift`.

Also documented the toolbar button group rule in CLAUDE.md under iOS UI Conventions:
- `HStack(spacing: 12)` for button groups
- `.padding(.horizontal, 8)` for edge breathing room
- `Divider().frame(height: 20)` between buttons as separators

Added a full UI Component Map to CLAUDE.md so screenshot-based references map to exact files.
