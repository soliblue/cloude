# Android Git Recent Commits {clock.arrow.circlepath}
<!-- priority: 13 -->
<!-- tags: android, git -->

> Show recent commits when working tree is clean.

## Desired Outcome
When git tab shows no staged or unstaged changes, display the 10 most recent commits with hash, message, author, and relative timestamp instead of empty space.

## iOS Reference Architecture

### Components
- `GitChangesView.swift` - commitsList view shown when no changes
- `GitCommitRow.swift` - individual commit rendering
- `GitChangesState.swift` - recentCommits storage

### Android implementation notes
- Request git log via WebSocket when git status returns clean
- Parse commit entries (hash, message, author, timestamp)
- Show in `GitScreen` when staged and unstaged lists are both empty
- Each row: abbreviated hash (accent color), message, author, relative time

**Files (iOS reference):** GitChangesView.swift, GitCommitRow.swift, GitChangesState.swift
