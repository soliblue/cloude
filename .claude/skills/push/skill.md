---
name: push
description: Commit and push to git (no deploy). Use when asked to "push", "commit", or "push to git".
user-invocable: true
icon: arrow.up.circle.fill
aliases: [commit, git]
---

# Push Skill

Commit and push changes to git without deploying.

## Security Check

**This is a PUBLIC repo. Before committing, review for:**
- API keys, tokens, secrets, passwords
- `.env` files or their contents
- Personal information, private URLs
- Keychain data, auth tokens

If unsure, ASK before committing.

## Steps

1. **Check testing gate**
   ```bash
   ls plans/30_testing/ 2>/dev/null | grep -c .md
   ```
   - If **5+ items** in `plans/30_testing/`, warn: "Testing queue is full (X items). Consider running /test before adding more."
   - Don't block the push, just warn.

2. **Review changes**
   ```bash
   git status
   git diff --stat
   git log --oneline -3
   ```

3. **Stage all changes**
   ```bash
   git add .
   ```

4. **Commit** with conventional prefix (`feat:`, `fix:`, `refactor:`, `docs:`, `chore:`):
   ```bash
   git commit -m "$(cat <<'EOF'
   feat: Short description

   - Details if needed

   Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
   EOF
   )"
   ```

5. **Push**
   ```bash
   git push
   ```

6. **Plan ticket check**
   After pushing, check if there's a matching plan in `plans/` for the work just committed:
   - If no matching plan exists, create a small plan file directly in `plans/30_testing/` describing what was just pushed
   - Every code change needs a plan ticket — this ensures nothing gets lost

## Important

- When invoked as a skill, push without asking for confirmation
- If sensitive data is detected, STOP and warn — don't push
- Include all agents' work, not just your own
- Use `git add .` to stage everything
