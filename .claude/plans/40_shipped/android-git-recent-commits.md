---
title: "Android Git Recent Commits"
description: "Show recent commits when working tree is clean."
created_at: 2026-04-05
tags: ["android", "git"]
build: 125
icon: clock.arrow.circlepath
---
# Android Git Recent Commits


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
