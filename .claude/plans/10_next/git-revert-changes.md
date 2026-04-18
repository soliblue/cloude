---
title: "Git Revert Changes"
description: "Add `Unstage All` and `Discard All` actions to the git tab section headers."
created_at: 2026-03-19
tags: ["git", "ui", "agent", "relay"]
icon: arrow.uturn.backward
build: 96
---


# Git Revert Changes {arrow.uturn.backward}
## Goal

Make bulk revert actions available directly in the git view without extra prompts.

## Actions

- `Unstage All` in the staged section
- `Discard All` in the changes section
- refresh git status automatically after either action

## Commands

Unstage all:
```bash
git restore --staged -- .
```

Discard all:
```bash
git restore --worktree -- .
git clean -f
```

## Required Work

- add shared client messages for both actions
- implement relay and Mac agent handlers
- expose connection manager helpers on iOS
- add the two buttons in `GitChangesView`

## Verification

- unstage all updates the staged section correctly
- discard all clears tracked and untracked changes
- git status refreshes automatically afterward
