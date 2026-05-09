---
title: "Git Refresh After Response"
description: "Fetch git changes after every successful Claude Code response to keep the git tab up to date."
created_at: 2026-05-06
updated_at: 2026-05-10
tags: ["git"]
icon: arrow.clockwise
---

# Git Refresh After Response

## Implementation

The iOS session view now keys git refresh by endpoint, path, worktree state, worktree head commit, and `session.lastSeq`. A completed stream advances the session sequence, so the git task reruns without the user leaving and returning to the git tab.

Worktree sessions also refresh when the worktree becomes ready or merged because the same key includes worktree state and head commit.

## Verify

- Send a message that changes a tracked file in a configured git session.
- Open the git tab after the response finishes and confirm the changed file appears without manual navigation.
- Repeat with a worktree session and confirm merged worktree changes still show in the git tab.
