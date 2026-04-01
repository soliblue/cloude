# Search Sheet Debounce {gauge.with.dots.needle.bottom.50percent}
<!-- priority: 20 -->
<!-- tags: ui, performance -->
> Debounce conversation search to avoid expensive per-keystroke filtering through all message text.

## Changes

- ConversationSearchSheet: 200ms debounce on search query, immediate clear on empty query

## Verify

Outcome: conversation search feels responsive while typing, with results appearing after a brief pause instead of recalculating on every keystroke.

Test: open the search sheet (cloude://search), type a query quickly, verify results appear smoothly without UI jank. Clear the search and verify the full list appears immediately.
