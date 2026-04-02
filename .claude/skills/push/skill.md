---
name: push
description: Commit and push to git without deploying.
user-invocable: true
metadata:
  icon: arrow.up.circle.fill
  aliases: [commit, git]
---

# Push

Commit and push changes without deploying.

## Before Pushing

Check for:
- secrets
- `.env` contents
- private URLs
- tokens or credentials
- personal information that should not be public

If unsure, stop and ask.

## Workflow

1. Check testing queue size in `.claude/plans/30_testing/` and warn if it is crowded.
2. Review changes with `git status`, `git diff --stat`, and recent commits.
3. Review the actual diff against CLAUDE.md project guidelines (style rules, architecture, naming). Flag any violations before proceeding.
4. If changes span multiple unrelated concerns and can easily be split, make separate focused commits. Only split when the grouping is obvious; do not over-engineer it.
5. Ensure every code change has a matching plan in `.claude/plans/40_done/`. If a plan exists in `20_active/` or `30_testing/`, move it to `40_done/`. If no plan exists, create one directly in `40_done/`.
6. Stage changes.
7. Commit with a conventional prefix.
8. Push.

## Rules

- Do not push sensitive data.
- Include all relevant work, not just your own edits.
- Every code change should map to a plan.
