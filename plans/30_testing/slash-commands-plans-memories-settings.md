# Slash Commands for Plans, Memories, Settings

Added `/plans`, `/memories`, and `/settings` as built-in slash commands:
- `/plans` opens the plans sheet (removed clipboard button from toolbar)
- `/memories` opens the memories sheet (brain button still in toolbar)
- `/settings` opens the settings sheet (accessible via status logo tap too)

## Changes
- `SlashCommand.swift`: added 3 new built-in commands
- `MainChatView+Messaging.swift`: intercepts for all 3 commands
- `MainChatView.swift`: plans state moved here + `onShowMemories`/`onShowSettings` closures
- `MainChatView+EventHandling.swift`: plans/planDeleted events handled here now
- `CloudeApp.swift`: removed plans button from toolbar, removed plans state/sheet/events, passes closures for memories/settings
