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

1. Check testing queue size in `plans/30_testing/` and warn if it is crowded.
2. Review changes with `git status`, `git diff --stat`, and recent commits.
3. Stage changes.
4. Commit with a conventional prefix.
5. Push.
6. If there is no matching plan, create one in `plans/30_testing/`.

## Rules

- Do not push sensitive data.
- Include all relevant work, not just your own edits.
- Every code change should map to a plan.
