---
name: reflect
description: Review and reorganize CLAUDE.md, CLAUDE.local.md, and recent conversation history.
user-invocable: true
metadata:
  icon: brain.head.profile
  aliases: [remember, memories, organize, tidy]
---

# Reflect

Review memory structure, suggest improvements, and surface things worth remembering.

## Workflow

1. Read `CLAUDE.md` and `CLAUDE.local.md`.
2. Read recent conversation history, usually the last 7 days.
3. Use a worker model to analyze:
   - reorganization opportunities
   - new memories worth saving
   - stale or redundant entries
4. Present suggestions first.
5. Wait for approval before writing anything.

## Rules

- `CLAUDE.md` is project doctrine.
- `CLAUDE.local.md` is personal continuity.
- Be conservative with deletions.
- Prefer structure over rewriting voice.
- Quality over quantity for new memories.
- Use real section hierarchy, not fake grouping with bold text.

## Output

Present:
- short summary
- reorganization suggestions
- new memories worth adding
- stale items worth reviewing

If helpful, ask `/consult codex` for a second opinion and present one unified view.
