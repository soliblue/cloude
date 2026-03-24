---
name: plan
description: Create, move, and manage plans (tickets). Use when asked to "plan", "create a ticket", "what's planned", or to move plans between stages.
user-invocable: true
icon: list.bullet.clipboard
aliases: [ticket, plans, 00_backlog]
---

# Plan Skill

Plans are lightweight ticket files that live in `.claude/plans/`. Each plan is a single markdown file that moves through folders as it progresses.

## Folder Structure

```
.claude/plans/
├── 00_backlog/    # Ideas and future work. Low priority, no timeline.
├── 10_next/       # Priority items. Pick from here when starting work.
├── 20_active/     # Currently being worked on by an agent.
├── 30_testing/    # Implemented, awaiting user testing.
└── 40_done/       # Completed and deployed. Archive.
```

## Lifecycle

```
00_backlog/ → 10_next/ → 20_active/ → 30_testing/ → 40_done/
```

- **00_backlog**: Anything worth remembering. Can skip straight to `10_next/` or `20_active/` if urgent.
- **10_next**: The user (or an agent) decided this is priority. Pick from here first.
- **20_active**: An agent is working on this RIGHT NOW. Move here when starting, move out when done.
- **30_testing**: Code is written, needs the user to verify on device. Corresponds to "Awaiting test" in CLAUDE.local.md staging.
- **40_done**: Tested and deployed. Keep for reference.

## Plan File Format

Filename: `kebab-case-description.md` (e.g., `compact-input-fields.md`)

### Required Metadata

Every plan MUST have these in the first few lines:

```markdown
# Feature Name {sf.symbol.name}
<!-- priority: 10 -->
<!-- tags: ui, agent -->
```

- **SF Symbol**: Append `{symbol.name}` to the title (e.g., `# My Feature {sparkles}`). Shown as icon in the Plans sheet.
- **Priority**: `<!-- priority: N -->` where lower = higher priority. Default to 10.
- **Tags**: `<!-- tags: comma, separated -->` for filtering. Common tags: ui, agent, markdown, conversations, windows, tools, cleanup, security, reliability, performance, teams, files, git, input, skills, messages, refactor.
- **Description**: A `> blockquote` line right after the metadata comments. Shown as subtitle on plan cards. Keep it to one sentence.
- **Build** (testing/done only): `<!-- build: N -->` added by deploy skill.

**Detail scales with stage** — 00_backlog is scannable, detail grows as plans move forward:

### Backlog (problem + desired outcome, <10 lines)
00_backlog items describe the **problem** and **desired outcome** only. No implementation details, no open questions, no code sketches. A sentence or two of approach is fine but keep it concise. The goal is scannability — anyone should understand what this is and why it matters in 5 seconds. Detail gets added when moving to `10_next/` or `20_active/`.

```markdown
# Feature Name {sf.symbol.name}
<!-- priority: 10 -->
<!-- tags: ui -->

> Short one-sentence description shown on plan cards.

One or two sentences describing the problem.

## Desired Outcome
What success looks like in one or two sentences. Can mention approach briefly.

**Files:** `relevant-file.swift`, `other-file.swift`
```

### Next (scoped, ~20-50 lines)
When promoting from 00_backlog, flesh out the approach: goals, rough plan, files, open questions. This is where you scope the work.

```markdown
# Feature Name {sf.symbol.name}
<!-- priority: 10 -->
<!-- tags: ui -->

> Short one-sentence description shown on plan cards.

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
ls .claude/plans/00_backlog/ .claude/plans/10_next/ .claude/plans/20_active/ .claude/plans/30_testing/
```

### Create a plan
Write a new file in the appropriate folder (usually `00_backlog/` or `10_next/`).

### Move a plan
```bash
# Promote to 10_next
mv .claude/plans/00_backlog/my-feature.md .claude/plans/10_next/

# Start working on it
mv .claude/plans/10_next/my-feature.md .claude/plans/20_active/

# Done coding, needs 30_testing
mv .claude/plans/20_active/my-feature.md .claude/plans/30_testing/

# Tested and deployed
mv .claude/plans/30_testing/my-feature.md .claude/plans/40_done/
```

### Pick 10_next work
Look in `10_next/` first, then `00_backlog/`. Read the plan, move to `20_active/`, start working.

## Review Plans with Codex

Send plans to Codex for review and pipe feedback directly into the plan file. Codex stays read-only — its output gets appended as a `## Codex Review` section.

### Single plan
```bash
PLAN=".claude/plans/10_next/my-feature.md"
echo -e "\n## Codex Review\n" >> "$PLAN" && \
codex exec -s read-only -C "$(git rev-parse --show-toplevel)" \
  "Review this plan for the Cloude project (iOS app + Mac agent for remote Claude Code). Give feedback on the approach, flag risks or missing considerations, and suggest improvements. Here is the plan: $(cat "$PLAN")" \
  >> "$PLAN"
```

### Batch review (all plans in a folder)
```bash
for plan in .claude/plans/10_next/*.md; do
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
- **Every code change needs a ticket** — if implementing an ad-hoc request with no existing plan, create a small plan directly in `30_testing/` after implementing it
- Only move your own plans (multi-agent coordination)
- Plans in `20_active/` should have at most 1-2 items per agent
- The `30_testing/` folder is the single source of truth for what needs testing — no need to duplicate in CLAUDE.local.md
- At **5+ items in testing/**, stop adding features and tell the user to test first
- Delete plan files only from `40_done/` if they're no longer useful as reference
- Keep plans concrete: diagrams, file lists, ASCII mockups over abstract descriptions
