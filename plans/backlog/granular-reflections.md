# Granular Reflections & Instant Skills

## Summary
Use conversation summaries to generate targeted, actionable outputs: new skills, refactor suggestions, memory updates, or pattern recognition — all scoped to what just happened rather than broad session-level reflection.

## Why
The current `/reflect` skill analyzes everything at once. But the most useful insights come right after specific work:
- "You just spent 20 minutes debugging a WebSocket issue — here's a skill for that"
- "This conversation touched 8 files in the same pattern — here's a refactor suggestion"
- "You asked about prediction markets 3 times this week — adding to interests"

## Ideas

### Instant Skills
After a conversation with significant tool usage, analyze the pattern and suggest a skill:
- "You ran `git status && git diff && git add . && git commit` — want a `/quick-commit` skill?"
- "You edited 5 SwiftUI views with the same pattern — want a `/add-toolbar` skill?"

### Targeted Refactor
After touching multiple files, analyze just those files for:
- Shared patterns that could be extracted
- Code that grew during the session and needs cleanup
- New abstractions suggested by the work that was done

### Memory Drip
Instead of big reflect sessions, continuously drip small memory updates:
- After each conversation, Haiku checks if anything is worth remembering
- Updates CLAUDE.local.md with small, specific entries
- Removes outdated entries when new info contradicts them

### Implementation Path
1. Start with conversation summaries (separate ticket)
2. Feed summaries into a "post-conversation analysis" Haiku call
3. Output: suggested skills, memory updates, refactor targets
4. Present to user for approval (not auto-applied)

## Dependencies
- Conversation Summaries feature (separate ticket)
- Skill creation infrastructure (already exists via skillsmith)
- Refactor analysis (already exists via /refactor)
