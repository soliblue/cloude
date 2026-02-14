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
