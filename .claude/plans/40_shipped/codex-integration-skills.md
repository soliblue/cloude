---
title: "Codex Integration in Skills"
description: "Added Codex second opinion step to refactor, reflect, and skillsmith skills for cross-model analysis."
created_at: 2026-02-07
tags: ["skills"]
icon: arrow.triangle.branch
build: 43
---


# Codex Integration in Skills {arrow.triangle.branch}
## Summary
Added Codex second opinion step to refactor, reflect, and skillsmith skills.

## Implementation
- **Refactor**: Asks Codex to review codebase for refactoring opportunities, compares with own analysis
- **Reflect**: Asks Codex to review memory organization, compares with Sonnet worker's analysis
- **Skillsmith**: Asks Codex to review skill ecosystem for gaps/extensions/deprecations, compares with Sonnet worker

All three use `codex exec -s read-only` for safety. Each presents a unified view noting agreements and differences between perspectives.

## Status
Done.
