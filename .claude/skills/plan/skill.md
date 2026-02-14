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
- **testing**: Code is written, needs the user to verify on device. Corresponds to "Awaiting test" in CLAUDE.local.md staging.
- **done**: Tested and deployed. Keep for reference.

## Plan File Format

Filename: `kebab-case-description.md` (e.g., `compact-input-fields.md`)

**Detail scales with stage** — backlog is scannable, detail grows as plans move forward:

### Backlog (problem + desired outcome, <10 lines)
Backlog items describe the **problem** and **desired outcome** only. No implementation details, no open questions, no code sketches. A sentence or two of approach is fine but keep it concise. The goal is scannability — anyone should understand what this is and why it matters in 5 seconds. Detail gets added when moving to `next/` or `active/`.

```markdown
# Feature Name

One or two sentences describing the problem.

## Desired Outcome
What success looks like in one or two sentences. Can mention approach briefly.

**Files:** `relevant-file.swift`, `other-file.swift`
```

### Next (scoped, ~20-50 lines)
When promoting from backlog, flesh out the approach: goals, rough plan, files, open questions. This is where you scope the work.

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

### Active (detailed, ~50-150 lines)
Full implementation detail. Code snippets, edge cases, step-by-step plan. This is the working document.

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

## Review Plans with Codex

Send plans to Codex for review and pipe feedback directly into the plan file. Codex stays read-only — its output gets appended as a `## Codex Review` section.

### Single plan
```bash
PLAN="plans/next/my-feature.md"
echo -e "\n## Codex Review\n" >> "$PLAN" && \
codex exec -s read-only -C "$(git rev-parse --show-toplevel)" \
  "Review this plan for the Cloude project (iOS app + Mac agent for remote Claude Code). Give feedback on the approach, flag risks or missing considerations, and suggest improvements. Here is the plan: $(cat "$PLAN")" \
  >> "$PLAN"
```

### Batch review (all plans in a folder)
```bash
for plan in plans/next/*.md; do
  echo -e "\n## Codex Review\n" >> "$plan" && \
  codex exec -s read-only -C "$(git rev-parse --show-toplevel)" \
    "Review this plan for the Cloude project (iOS app + Mac agent for remote Claude Code). Give feedback on the approach, flag risks or missing considerations, and suggest improvements. Here is the plan: $(cat "$plan")" \
    >> "$plan"
done
```

### Instructions
1. **Always set `timeout: 300000`** (5 min) on each Bash call
2. For batch reviews, run as **parallel background tasks** for speed
3. Codex stays `-s read-only` — reads codebase for context, never writes
4. Review appends directly to the plan file as a permanent record
5. If a plan already has a `## Codex Review` section, remove the old one before appending

## Rules

- One plan per feature/bug/idea
- **Every code change needs a ticket** — if implementing an ad-hoc request with no existing plan, create a small plan directly in `testing/` after implementing it
- Only move your own plans (multi-agent coordination)
- Plans in `active/` should have at most 1-2 items per agent
- The `testing/` folder is the single source of truth for what needs testing — no need to duplicate in CLAUDE.local.md
- At **5+ items in testing/**, stop adding features and tell the user to test first
- Delete plan files only from `done/` if they're no longer useful as reference
- Keep plans concrete: diagrams, file lists, ASCII mockups over abstract descriptions
