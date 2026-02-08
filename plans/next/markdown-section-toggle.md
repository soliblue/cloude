# Markdown Section Toggle {chevron.down.square}

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
