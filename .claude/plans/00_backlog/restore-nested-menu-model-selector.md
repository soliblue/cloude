# Restore Nested Menu for Model/Effort Selector {filemenu.and.selection}
<!-- priority: 5 -->
<!-- tags: ui -->

> Restore the old nested model and effort selector once taps work reliably again.

The model and effort selectors in the send button menu used to be nested `Menu` components (sub-menus) which looked more native. They stopped responding to taps, likely an iOS system-level regression with nested Menu inside Menu with `primaryAction`. Currently using `Picker` as a workaround which works but looks less polished.

## Desired Outcome
Restore the original nested Menu appearance for effort/model selection, or find an alternative that matches it visually while remaining functional.

## Context
- Tested both `@ViewBuilder var` extraction AND fully inlined nested menus. Same result: taps don't register. Not a code issue.
- `Picker` in the same position works perfectly, confirming state management is fine.
- Broke sometime around March 2026, likely an iOS update.

**Files:** `GlobalInputBar+ActionButton.swift`
