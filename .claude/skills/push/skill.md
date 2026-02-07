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

1. **Review changes**
   ```bash
   git status
   git diff --stat
   git log --oneline -3
   ```

2. **Stage all changes**
   ```bash
   git add .
   ```

3. **Commit** with conventional prefix (`feat:`, `fix:`, `refactor:`, `docs:`, `chore:`):
   ```bash
   git commit -m "$(cat <<'EOF'
   feat: Short description

   - Details if needed

   Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
   EOF
   )"
   ```

4. **Push**
   ```bash
   git push
   ```

## Important

- When invoked as a skill, push without asking for confirmation
- If sensitive data is detected, STOP and warn — don't push
- Include all agents' work, not just your own
- Use `git add .` to stage everything
