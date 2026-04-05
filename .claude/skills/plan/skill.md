---
name: plan
description: Create, move, and manage plan tickets in `.claude/plans/`.
user-invocable: true
metadata:
  icon: list.bullet.clipboard
  aliases: [ticket, plans, 00_backlog]
---

# Plan

Plans are markdown tickets in `.claude/plans/`.

## Stages

```text
00_backlog -> 10_next -> 20_active -> 30_testing -> 40_done
```

- `00_backlog`: worth remembering
- `10_next`: prioritized next
- `20_active`: currently being worked on
- `30_testing`: implemented, waiting for user verification
- `40_done`: tested and finished

## File Format

Filename: `kebab-case-description.md`

Required header:

```markdown
# Feature Name {sf.symbol.name}
<!-- priority: 10 -->
<!-- tags: ui, agent -->
> One sentence description.
```

Optional for testing/done:

```markdown
<!-- build: N -->
```

## Testing Handoff

Before moving a ticket to `30_testing`, it must contain a `## Verify` section describing:

1. **Desired outcome** on a high level (what should be true after the change).
2. **A simple test** another agent can execute to confirm the outcome.

Keep it as short as possible but not shorter. The `sim` skill picks up tickets in `30_testing` and uses this section to run QA autonomously.

Example:

```markdown
## Verify

Outcome: tapping the plans tab deep-links to the plans sheet with all stages visible.

Test: open `cloude://plans`, capture a screenshot, confirm all five stage headers render.
```

## Rules

- Backlog items stay short and scannable.
- Detail grows as a plan moves forward.
- Every real change should have a plan.
- Use SF Symbol icons in titles.
- Prefer clarity over exhaustiveness.

## Tagging

Use 1 or 2 tags per plan, not more.

Start with this shared core vocabulary:
- `ui`
- `agent`
- `skills`
- `memory`
- `git`
- `files`
- `settings`
- `streaming`

This is the default tag set, not a permanently closed list.

Add a new tag only when the existing tags clearly cannot express a distinct recurring kind of work. Avoid synonyms and near-duplicates. If a new tag is introduced, update this `SKILL.md` section so the shared vocabulary stays explicit for future instances. If multiple tags drift into the same meaning over time, consolidate them later.
