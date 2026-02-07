---
name: plan
description: Create, move, and manage plans (tickets). Use when asked to "plan", "create a ticket", "what's planned", or to move plans between stages.
user-invocable: true
icon: list.bullet.clipboard
aliases: [ticket, plans, backlog]
---

# Plan Skill

Plans are lightweight ticket files that live in `plans/`. Each plan is a single markdown file that moves through folders as it progresses.

## Folder Structure

```
plans/
├── backlog/    # Ideas and future work. Low priority, no timeline.
├── next/       # Priority items. Pick from here when starting work.
├── active/     # Currently being worked on by an agent.
├── testing/    # Implemented, awaiting Soli's testing.
└── done/       # Completed and deployed. Archive.
```

## Lifecycle

```
backlog/ → next/ → active/ → testing/ → done/
```

- **backlog**: Anything worth remembering. Can skip straight to `next/` or `active/` if urgent.
- **next**: Soli (or an agent) decided this is priority. Pick from here first.
- **active**: An agent is working on this RIGHT NOW. Move here when starting, move out when done.
- **testing**: Code is written, needs Soli to verify on device. Corresponds to "Awaiting test" in CLAUDE.local.md staging.
- **done**: Tested and deployed. Keep for reference.

## Plan File Format

Filename: `kebab-case-description.md` (e.g., `compact-input-fields.md`)

Scale detail to complexity:

### Small (backlog idea, ~10 lines)
```markdown
# Feature Name

One-line description of what and why.

## Files
- List of files affected

## Notes
- Any constraints or context
```

### Medium (next/active, ~50-150 lines)
```markdown
# Feature Name

Background and motivation.

## Goals
- What success looks like

## Approach
- How to implement it

## Files
- What changes where

## Open Questions
- Decisions not yet made
```

### Large (architectural, 150+ lines)
```markdown
# Feature Name

## Background
Problem, root cause, why now.

## Current Architecture
Diagrams, flow descriptions.

## Target Architecture
What it should look like after.

## Implementation Phases
1. Phase 1: ...
2. Phase 2: ...

## Edge Cases
## Risks
## Open Questions
```

## Commands

### Show plans
```bash
# List all plans by stage
ls plans/backlog/ plans/next/ plans/active/ plans/testing/
```

### Create a plan
Write a new file in the appropriate folder (usually `backlog/` or `next/`).

### Move a plan
```bash
# Promote to next
mv plans/backlog/my-feature.md plans/next/

# Start working on it
mv plans/next/my-feature.md plans/active/

# Done coding, needs testing
mv plans/active/my-feature.md plans/testing/

# Tested and deployed
mv plans/testing/my-feature.md plans/done/
```

### Pick next work
Look in `next/` first, then `backlog/`. Read the plan, move to `active/`, start working.

## Rules

- One plan per feature/bug/idea
- **Every code change needs a ticket** — if implementing an ad-hoc request with no existing plan, create a small plan directly in `testing/` after implementing it
- Only move your own plans (multi-agent coordination)
- Plans in `active/` should have at most 1-2 items per agent
- The `testing/` folder is the single source of truth for what needs testing — no need to duplicate in CLAUDE.local.md
- At **5+ items in testing/**, stop adding features and tell Soli to test first
- Delete plan files only from `done/` if they're no longer useful as reference
- Keep plans concrete: diagrams, file lists, ASCII mockups over abstract descriptions
