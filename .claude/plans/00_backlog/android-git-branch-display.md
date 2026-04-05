# Android Git Branch Display {arrow.triangle.branch}
<!-- priority: 13 -->
<!-- tags: android, git, ui -->

> Show current git branch name in window tab bar.

## Desired Outcome
Display the current git branch name next to the git icon in the window tab bar. Middle-truncate long branch names.

## iOS Reference Architecture

### Components
- `MainChatView+WindowHeader.swift` - tracks branch name from gitStatus event

### Android implementation notes
- Parse branch name from git status WebSocket messages
- Store in `EnvironmentConnection` or `WindowManager`
- Display in `WindowTabBar` next to the git changes icon
- Use `TextOverflow.Ellipsis` with `maxLines = 1` for long names

**Files (iOS reference):** MainChatView+WindowHeader.swift
