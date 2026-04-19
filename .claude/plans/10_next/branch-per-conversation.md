---
title: "Branch-per-Conversation via Git Worktrees"
description: "Isolate each conversation's git state with worktrees so branch switches do not leak across sessions."
created_at: 2026-03-24
tags: ["git", "relay", "agent"]
icon: arrow.triangle.branch
build: 103
---


# Branch-per-Conversation via Git Worktrees
## Problem

All conversations share one working directory. If one conversation changes branches, every other conversation sees the same switch.

## Approach

- Let a conversation optionally attach to a branch.
- Create a git worktree for that branch at `<repo>/.cloude-worktrees/<sanitized-branch>/`.
- Override that conversation's working directory with the worktree path.
- Keep detach lightweight by restoring the original working directory and leaving worktree cleanup manual or prunable.

## Required Work

- add attach/list branch messages in shared models
- add relay handlers for branch listing and worktree creation
- add conversation fields for attached branch, worktree path, and original working directory
- add UI in the window edit sheet for attaching and detaching branches

## Verification

- list branches from the active repo
- attach a branch and verify the worktree is created
- confirm chat, files, and git views operate inside the worktree
- detach and verify the conversation returns to the original working directory
