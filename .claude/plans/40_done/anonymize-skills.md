# Anonymize Skills for Public Repo

## Goal
Make all skills generic so anyone cloning the repo can use them without editing hardcoded personal references.

## What Needs Changing

### Hardcoded absolute paths
Every skill references `./...` — should use relative paths or a `$PROJECT_ROOT` variable.

### Personal name references
- "Soli" appears in ~15 skills as the owner/user — replace with generic "the user" or remove
- `@_xSoli` Twitter handle in tweets skill
- `Soli's ChatGPT Pro subscription` in video skill
- `My iPhone` in deploy skill
- Manifold username/profile URL

### Knowunity references
- slides skill: `HOW_IT_WAS_MADE.md` and `presentation-notes.md` reference Knowunity branding
- Consider moving these to a gitignored `data/` folder or making them generic examples

### Account-specific config
- Manifold credentials baked into skill definition
- Goodreads RSS feed URL
- Moltbook username

## Approach
- Introduce a `$PROJECT_ROOT` or detect it dynamically so paths aren't hardcoded
- Replace personal names with generic references
- Move account-specific config (usernames, URLs) into `.env` or a gitignored config file
- Keep skill definitions generic, let CLAUDE.local.md hold the personal context
