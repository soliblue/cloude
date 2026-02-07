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

After completing your analysis, ask Codex for its take:

```bash
codex exec -s read-only -C /Users/soli/Desktop/CODING/cloude "Review this codebase for refactoring opportunities. Focus on dead code, unclear naming, duplicated logic, and overly complex functions. Be specific about files and line numbers."
```

Compare Codex's suggestions with your own and present a unified list, noting where you agree and where you differ.
