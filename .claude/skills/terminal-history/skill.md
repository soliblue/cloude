---
name: terminal-history
description: Search shell command history — find past commands, recent activity, usage stats. Reads zsh/bash history files directly, no dependencies.
user-invocable: true
icon: terminal
aliases: [shell-history, history, commands]
---

# Terminal History Skill

Search and analyze shell command history from zsh and bash history files. Reads `~/.zsh_history` (primary) with `~/.bash_history` as fallback.

## Scripts

### Search history by pattern
```bash
bash .claude/skills/terminal-history/history-search.sh "pattern" [limit]
```
- `pattern`: grep pattern to match against commands
- `limit`: max results (default 30)
- Output: `Date|Command` — most recent matches first

### Recent commands
```bash
bash .claude/skills/terminal-history/history-recent.sh [limit]
```
- `limit`: number of recent commands (default 50)
- Output: `Date|Command`

### Command usage stats
```bash
bash .claude/skills/terminal-history/history-stats.sh [limit]
```
- `limit`: top N commands (default 20)
- Output: `Count|Command` — grouped by first word, sorted by frequency

## Use Cases
- "What git commands did I run today?"
- "When did I last deploy?"
- "What are my most used commands?"
- "Show me recent docker commands"
- "Find that curl command I ran last week"
