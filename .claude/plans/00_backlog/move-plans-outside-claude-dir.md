# Move Plans Directory Outside .claude/ {folder.badge.gearshape}
<!-- priority: 3 -->
<!-- tags: agent -->

> Move plans out of `.claude` so plan files are easier for tools to edit directly.

`.claude/` is treated as sensitive by Claude Code -- Write/Edit tools always require approval there, even with explicit permission rules. Moving plans to a normal directory fixes this permanently.

## Goals
- Plans live at `.claude-plans/` (or `plans/`) in the repo root, not `.claude/plans/`
- Write/Edit tools work on plan files without approval prompts
- All references updated to point to the new location

## Approach
- `git mv .claude/plans .claude-plans` (preserves history)
- Update `CLAUDE.md` -- plan skill instructions, folder structure diagram, UI component map note
- Update `.claude/skills/plan.md` -- all path references
- Update any hardcoded `.claude/plans/` paths in skills (deploy, status, test, etc.)
- Check `settings.json` for `plansDirectory` setting -- can point Claude Code to new path

## Files
- `.claude/skills/plan.md` -- update all path references
- `CLAUDE.md` -- update structure + notes sections
- All other skills that reference `.claude/plans/`
- `.claude/settings.json` (new) -- set `plansDirectory: ".claude-plans"`

## Notes
- `plansDirectory` in settings.json is relative to project root -- can just set this and skip renaming if preferred
