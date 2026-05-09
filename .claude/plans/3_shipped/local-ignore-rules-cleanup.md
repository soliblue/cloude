---
title: "Local Ignore Rules Cleanup"
description: "Remove stale ignore rules and keep current local runtime files out of commits."
created_at: 2026-05-10
updated_at: 2026-05-10
tags: ["settings"]
icon: eye.slash
---

# Local Ignore Rules Cleanup

## Implementation

The ignore rules now cover `.claude/worktrees`, `.claude/scheduled_tasks.lock`, local Claude settings, credentials, local CLAUDE notes, and `.claude/memory`. Stale ignore entries for missing old skill and runtime directories were removed, and the tracked scheduled task lock file was deleted.

## Verify

- Run `git status --ignored --short .claude .gitignore`.
- Confirm worktrees, memory, scheduled task locks, local settings, and credentials are ignored.
- Confirm no removed ignore pattern corresponds to an existing untracked runtime directory that should stay private.
