# Conversation Search {magnifyingglass}
<!-- priority: 2 -->
<!-- tags: ui, search, feature -->

> Search across all conversations by content, name (including old names), and plans.

## Problem

With many conversations, finding a specific past discussion is impossible without remembering the exact current name. Need full-text search across conversation history.

## Design Decision

Search icon lives in the switcher bar with dividers separating the three sections:

```
[heart] | [window dots + plus] | [magnifyingglass]
```

Divider after heart, divider before search. Tapping search opens a search sheet/view.

## Plan

- Add `magnifyingglass` button to right side of switcher in `MainChatView+PageIndicator.swift`
- Add `Divider().frame(height: 20)` between heart and windows, and between windows and search
- Search sheet: text field + results list
- Search by: current name, old names (from name history), message content
- Results show matching conversations with preview/context snippet
- If result matched an old name, show it as secondary label (e.g. "formerly: Keen Snowglobe")
- Tapping a result switches to that conversation

## Depends On
- `conversation-name-history.md` (for searching old names)

## Files
- `Cloude/Cloude/UI/MainChatView+PageIndicator.swift` — add dividers + search button
- New search sheet view
