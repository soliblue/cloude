# Codex Integration in Skills

## Summary
Added Codex second opinion step to refactor, reflect, and skillsmith skills.

## Implementation
- **Refactor**: Asks Codex to review codebase for refactoring opportunities, compares with own analysis
- **Reflect**: Asks Codex to review memory organization, compares with Sonnet worker's analysis
- **Skillsmith**: Asks Codex to review skill ecosystem for gaps/extensions/deprecations, compares with Sonnet worker

All three use `codex exec -s read-only` for safety. Each presents a unified view noting agreements and differences between perspectives.

## Status
Done.
