---
title: "Git Log / Recent Commits"
description: "Show recent commits in the git tab when the working tree is clean."
created_at: 2026-04-02
tags: ["git", "ui", "agent", "relay"]
icon: clock.arrow.circlepath
build: 122
---


# Git Log / Recent Commits
## Changes

- `GitCommit` model in CloudeShared
- `gitLog` client/server message pair across CloudeShared, Mac agent, and linux-relay
- `GitService.getLog` on the Mac agent
- `handleGitLog` on the linux-relay
- `GitChangesState` tracks `recentCommits`
- `GitChangesView` shows commit list when no staged/unstaged changes
- `GitCommitRow` renders individual commits with hash, message, author, relative date
- `ConnectionEvent.gitLog` and wiring through ConnectionManager+API and MessageHandler
