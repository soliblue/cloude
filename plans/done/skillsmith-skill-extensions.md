# Skillsmith-Driven Skill Extensions

## What
Extended 4 skills and resolved 1 cleanup item based on /skillsmith analysis:

1. **`/push`** — Added testing gate (warns at 5+ items in plans/testing/) and plan ticket check (auto-creates ticket if none exists)
2. **`/deploy`** — Added `--mac-only` and `--ios-only` flags, updated post-deploy tracking to use plans/testing/ instead of CLAUDE.local.md staging
3. **`/test`** — Added `--run` flag (xcodebuild test), `--done <name>` flag, prominent item count
4. **`/status`** — Now checks plans/testing/ count first, shows commits since last deploy, lists active + next plans
5. **Staging cleanup** — Deploy skill no longer maintains separate feature states in CLAUDE.local.md. plans/testing/ is single source of truth.

Also updated /refactor, /reflect, and /skillsmith to require Soli's approval before implementing suggestions, with plan ticket creation when approved.

## Why
Skillsmith analysis showed skills were underused (3 invocations in 7 days) and all top patterns were natural coding flow. Extensions to existing skills were the only worthwhile improvements.
