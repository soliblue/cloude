---
name: refactor
description: Analyze the codebase for simplification and architectural improvement.
user-invocable: true
metadata:
  icon: wand.and.stars
  aliases: [cleanup, simplify, improve]
---

# Refactor

Analyze the codebase and propose improvements without fighting the existing architecture.

## Principles

- Small files are fine.
- Do not merge files for the sake of fewer files.
- Focus on dead code, duplication, naming, real complexity, and hardcoded values.
- Suggest abstractions only when they are earned.

## Analysis

```bash
find ./Cloude -type f -name "*.swift" | wc -l
find ./Cloude -type f -name "*.swift" -exec wc -l {} \; | sort -rn | head -20
```

Look for:
- dead code
- unused imports
- unclear naming
- duplicated logic
- overly complex functions
- missing abstractions with repeated payoff
- large files that should split
- hardcoded design values that should use tokens

Do not suggest:
- consolidation for its own sake
- bigger files as a simplification tactic
- abstractions with no clear payoff

## Output

Provide:
1. specific files or functions
2. why the change helps
3. what the change should look like

Present suggestions first and wait for approval before implementing. If approved, create a plan ticket in `plans/20_active/` or `plans/30_testing/`.

## Second Opinion

Use `/consult codex` sequentially, not in parallel. Either you lead and Codex reviews, or Codex leads and you review. Present one unified list.
