# UI Component Extraction Refactor {square.on.square.squareshape.controlhandles}
<!-- priority: 10 -->
<!-- tags: ui, refactor -->
<!-- build: 56 -->

> Deduplicated conversation headers, extracted subviews from ChatMessageList, and simplified StreamingMarkdownParser.

## Status: Active

## Tasks
1. **Deduplicate conversation header views** — `WindowHeaderView` (ConversationView+Components.swift:5) and `windowHeader(for:)` (MainChatView.swift:266) implement the same concept differently. Consolidate into one.
2. **Extract subviews from ChatMessageList.body** — Break deeply nested body into smaller computed properties: cost banner, message list, streaming, question view, scroll controls.
3. **Simplify StreamingMarkdownParser.parse()** — Extract per-block-type parsing into separate methods, keep parse() as thin dispatcher.

## Files Modified
- `Cloude/Cloude/UI/ConversationView+Components.swift`
- `Cloude/Cloude/UI/MainChatView.swift`
- `Cloude/Cloude/UI/StreamingMarkdownParser.swift`
