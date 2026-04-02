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

- Small files are fine. Do not merge files for the sake of fewer files.
- Focus on dead code, duplication, naming, real complexity, and style violations.
- Suggest abstractions only when they are earned (2+ real consumers).

## Analysis

```bash
find ./Cloude -type f -name "*.swift" | wc -l
find ./Cloude -type f -name "*.swift" -exec wc -l {} \; | sort -rn | head -20
```

Look for:

### Dead code & imports
- Unused code, unreachable branches, unused imports

### Style violations
- Comments (inline, docstrings, headers) - remove all
- try-catch blocks not explicitly requested - let errors propagate
- Single-use variables - return or use the expression directly
- Single-use functions - inline the logic
- Guard clauses checking for failure - always check for success (`if let x = y { use(x) }`)
- Em dashes anywhere in code or strings

### Design system violations
- Hardcoded colors, spacing, fonts, opacities, durations - must use `DS.*` / `AppTheme` / `Theme.swift` tokens
- `Spacer().frame(width:)` or `Spacer().frame(height:)` for fixed gaps - use `HStack(spacing:)` / `VStack(spacing:)` instead
- Standalone icons not using `DS.Icon` sizes
- Inline icons next to text not using matching `DS.Text` size
- Toolbar icons not using `DS.Icon.m`
- Multiple toolbar buttons missing `HStack(spacing: DS.Spacing.m)` wrapper

### Architecture violations
- Files >150 lines that should split with `Parent+Feature.swift` extensions
- Multiple components in one file (one struct/class/enum per file)
- View files containing logic, or logic files importing SwiftUI
- Features reaching into another feature's internals (cross-feature imports of public stores/models are fine)
- Code in `Shared/` with fewer than 2 real consumers
- Sheets using custom HStacks instead of `NavigationStack` + `.toolbar`
- Feature-local code placed in `Shared/` instead of under the owning feature

### Naming & duplication
- Unclear or inconsistent naming
- Duplicated logic across files

## Do not suggest

- Consolidation for its own sake
- Bigger files as a simplification tactic
- Abstractions with no clear payoff
- Adding comments, docstrings, or type annotations

## Output

Provide:
1. Specific files or functions
2. Why the change helps
3. What the change should look like

Present suggestions first and wait for approval before implementing. If approved, create a plan ticket in `.claude/plans/20_active/` or `.claude/plans/30_testing/`.

## Second Opinion

Use `/consult codex` sequentially, not in parallel. Either you lead and Codex reviews, or Codex leads and you review. Present one unified list.
