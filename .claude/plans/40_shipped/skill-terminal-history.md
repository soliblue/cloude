---
title: "Skill: Terminal History"
description: "Built terminal history skill for searching and analyzing shell command history."
created_at: 2026-02-14
tags: ["skills"]
icon: terminal
build: 71
---


# Skill: Terminal History
## What
Search and analyze shell command history from zsh/bash.

## Scripts
- `history-search.sh` — Search history by grep pattern
- `history-recent.sh` — Show N most recent commands
- `history-stats.sh` — Most frequently used commands

## Permissions Needed
- None (reads ~/.zsh_history)

## Testing
- [ ] `history-search.sh git 10` finds git commands
- [ ] `history-recent.sh 20` shows recent commands
- [ ] `history-stats.sh 15` shows command frequency
