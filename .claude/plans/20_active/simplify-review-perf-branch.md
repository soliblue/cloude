# Simplify Review of Perf Branch

Tags: performance, review

## Context

The `experiment-refactor-no-perf` branch has 8 unpushed commits focused on streaming performance. A four-pass review (simplify, perf investigator, codex consult, refactor) produced a consolidated action list. This plan covers the safe fixes and dead code cleanup.

## Consolidated Findings

### Fix now (safe, no behavior change)

1. **Dead ternary branch** - `StreamingMarkdownView.swift:61` - both branches identical, `textChanged` variable is dead too. Collapse to plain call.
2. **tailBlocks.map in body** - `StreamingMarkdownView.swift:31` - move `.prefixed("tail-")` into `updateIncremental()` to avoid 60Hz array allocation in body.
3. **Double .map(LiveToolRenderState.init)** - `MessageBubble+LiveWrapper.swift:64` - replace with zip-based or index-walk comparison to avoid 120 temp arrays/sec.

### Dead code to delete

4. **StreamingMarkdownRenderer.swift** - zero external references, replaced by inline @State approach.
5. **ToolGroupLayout.swift** - zero external references, replaced by inline toolHierarchy.
6. **ConversationHeaderView** (in WorkspaceView+ConversationInfo.swift) - zero call sites after showHeader removal.

### Intentional tradeoffs (do not touch)

7. Tool-call path bypasses frozen blocks - rollback of broken a9dc2391.
8. ToolGroupView lost Equatable - removed to fix same-group rename bug. Future perf round candidate.
9. FrozenBlocksSection equality weakened - acceptable for append-only text.

### Low priority (skip for now)

10. toolHierarchy computed 3x - real but tiny cost.
11. toolRevision string construction - small, not worth optimizing without profiling.
12. 10 @State vars - readability preference, already tried grouping and moved back.

### Noted but not introduced by this branch

13. Hardcoded animation durations (0.2, 0.01, 0.6) instead of DS.Duration tokens.
14. Multiple structs per file in StreamingMarkdownView+ToolGroup.swift.
15. ConversationView.swift has business logic (handleCompletion) in a view file.

## Plan

- Fix items 1-3 (code quality)
- Delete items 4-6 (dead code)
- Build and test end-to-end on simulator
- Squash all commits (8 existing + fixes) into one battle-tested commit

## Status

In progress.

## Decision

Pending user confirmation of squash commit.
