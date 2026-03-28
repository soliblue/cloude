# Git Revert Changes {arrow.uturn.backward}
<!-- priority: 5 -->
<!-- tags: git, ui, agent, relay -->

> Add `Unstage All` and `Discard All` actions to the git tab section headers.

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
