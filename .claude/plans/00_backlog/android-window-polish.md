# Android Window Edit Polish {pencil.circle}
<!-- priority: 14 -->
<!-- tags: android, windows, ux -->

> Window icon picker, animated conversation info label, and reading progress indicator.

## Context

iOS has three UX features around windows and navigation that Android lacks:
1. **Window icon picker** - Each window can have a custom icon from a searchable picker (18 categories, grid layout)
2. **Conversation info label** - The nav bar title is a tappable pill showing icon, name (with animated text transitions), working directory, and cost
3. **Reading progress** - A subtle indicator showing scroll position within the conversation

## Scope

### Window Icon Picker
- Add icon selection to window edit/settings
- Material Icons picker with category tabs and search
- Persist icon per window in WindowManager

### Conversation Info Label
- Replace plain title text with a tappable chip showing: window icon, conversation name, working directory basename
- Tap opens window edit sheet
- Animated name transitions when conversation changes

### Reading Progress
- Thin progress bar at top of chat scroll (position / total height)
- Fades out when at bottom, shows when scrolled up

## Dependencies

None
