# Markdown Section Toggle {chevron.down.square}
<!-- priority: 4 -->
<!-- tags: markdown -->

> Collapsible markdown headers that don't shift text position when toggling — tap to collapse/expand body content underneath.

## Problem
Markdown headers in messages (##, ###) could act as collapsible sections, but the current arrow-based disclosure indicators shift the header text when toggling. This violates our UX principle of minimizing content movement — users shouldn't have to chase text that jumps around.

## Idea
Replace the arrow/chevron disclosure with a toggle mechanism that doesn't shift the header text position. Options:
- Subtle background color change or highlight on the header when collapsed
- A small indicator in the margin/gutter rather than inline
- Tap the header itself to toggle, with only the body collapsing underneath
- An opacity or styling change on the header (e.g., dimmed = collapsed)

## Requirements
- Header text must NOT move horizontally when toggling open/closed
- Body content below collapses/expands smoothly
- Collapsed state should be visually obvious without adding inline indicators
- Works for ##, ###, and deeper headers

## Open Questions
- Which headers should be collapsible? All of them or only ## and ###?
- Should sections start collapsed or expanded by default?
- How to handle nested headers (### inside ##)?
- Should collapsed state persist across scrolling or reset?

## Codex Review

**Findings (Highest Risk First)**
1. High: "No inline indicators" can hurt discoverability and accessibility. If a header is collapsed with only subtle styling, users may miss that content exists.
2. High: Nested sections are underspecified. If `##` and child `###` are both collapsible, toggle behavior can become ambiguous (parent collapse should dominate children, but child state should still be retained).
3. High: State identity is not defined. If collapse state is keyed by rendered position instead of a stable section ID, it will break when messages update/stream/edit.
4. Medium: Animation/perf risk on long messages. Expanding/collapsing many rich markdown blocks can cause scroll jumps or dropped frames if layout is recalculated naively.
5. Medium: Persistence scope is unclear. "Persist across scrolling" is too narrow; you also need behavior for app background/foreground, message rerender, conversation reload.
6. Medium: Interaction conflicts not covered. Header tap may conflict with text selection, link taps, and VoiceOver rotor navigation.
7. Low: Requirement says "deeper headers" but open question asks maybe only `##`/`###`; this should be decided early to avoid rework.

**Improvements to the Approach**
1. Use a fixed, always-reserved left gutter hit area for collapse affordance (even if visually minimal). This guarantees header text x-position never changes.
2. Keep header typography/position constant; only animate body container height + alpha.
3. Define deterministic rules: collapsible levels `##` and `###` only; parent collapse hides all descendants; child collapsed states remembered when parent re-expands.
4. Define stable section IDs (e.g., messageID + header AST path/hash) for state storage.
5. Default behavior: expanded by default; remember per-message state during session, optionally persist per-thread.
6. Add accessibility semantics: header exposes expanded/collapsed state and "double tap to expand/collapse."
7. Add guardrails for streaming content: avoid auto-collapsing newly arriving sections unless user explicitly toggled.

**Missing Considerations**
1. Copy/share behavior: when copying message text, include collapsed content or only visible content?
2. Search/find-in-page behavior: should matches inside collapsed sections auto-expand?
3. Deep-linking/jump-to-heading: should target heading auto-expand ancestor chain?
4. QA matrix: light/dark mode, Dynamic Type, VoiceOver, RTL, long documents, nested 4+ levels.

**Suggested Decision Set (to unblock implementation)**
1. V1: only `##` and `###`, default expanded.
2. Fixed gutter affordance + subtle collapsed header styling.
3. Session persistence per message, keyed by stable section ID.
4. Parent/child rule: parent collapse wins, child state retained.
5. Add accessibility labels/traits and test for VoiceOver + Dynamic Type.
