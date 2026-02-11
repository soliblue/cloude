---
name: refactor
description: Analyze the codebase for improvements. Use when asked to simplify, clean up, or improve architecture.
user-invocable: true
icon: wand.and.stars
aliases: [cleanup, simplify, improve]
---

# Refactor Skill

Analyze the codebase and propose improvements while respecting the existing architecture.

## Philosophy

- **Small files are good** - easier to find, cleaner diffs, single responsibility
- **Don't merge for the sake of fewer files** - file count is not a problem
- **Focus on real issues** - dead code, unused dependencies, unclear naming, actual complexity

## Analysis Steps

### 1. Current State

```bash
find ./Cloude -type f -name "*.swift" | wc -l
find ./Cloude -type f -name "*.swift" -exec wc -l {} \; | sort -rn | head -20
```

### 2. Look For

- **Dead code** - unused functions, unreachable branches, commented-out code
- **Unused imports** - imports that aren't needed
- **Unclear naming** - vague names, inconsistent conventions
- **Duplicated logic** - same code in multiple places (extract if 3+ uses)
- **Overly complex functions** - functions doing too many things
- **Missing abstractions** - repeated patterns that should be formalized
- **Large files** - files over 500 lines that might benefit from splitting

### 3. Do NOT Suggest

- Merging small files together
- Reducing file count as a goal
- "Simplifying" by making fewer, larger files
- Consolidation for its own sake

## Output

Provide actionable improvements:
1. Specific files/functions to change
2. Why the change improves the code
3. What the change looks like

**Present suggestions to Soli and wait for approval.** Do NOT implement any changes until Soli says to. When Soli approves specific suggestions, create a plan ticket in `plans/active/` (or `plans/testing/` if implementing immediately) for each approved change.

## Second Opinion (Codex)

**IMPORTANT: Sequential, not parallel.** Randomly pick one of these two orderings each time:

**Option A** — You go first, Codex reviews:
1. Complete your full analysis first
2. Then ask Codex to review your findings and add anything you missed

**Option B** — Codex goes first, you review:
1. Ask Codex to do the initial analysis
2. Then review Codex's findings, add your own, and filter out bad suggestions

Either way, **never run Codex in parallel with your own analysis**. One leads, the other reviews. This produces better results than two independent analyses.

Use the `/consult codex` skill to get Codex's perspective:

```bash
/consult codex "Review this codebase for refactoring opportunities. Read .claude/skills/refactor/SKILL.md first — it contains the analysis criteria and philosophy. Suggest specific improvements with file paths and line numbers."
```

Present a unified list, noting where you agree and where you differ.
