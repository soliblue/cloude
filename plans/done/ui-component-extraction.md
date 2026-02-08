# UI Component Extraction Refactor
<!-- priority: 10 -->
<!-- tags: ui -->
<!-- build: 56 -->

## Status: Active

## Tasks
1. **Deduplicate conversation header views** — `WindowHeaderView` (ConversationView+Components.swift:5) and `windowHeader(for:)` (MainChatView.swift:266) implement the same concept differently. Consolidate into one.
2. **Extract subviews from ChatMessageList.body** — Break deeply nested body into smaller computed properties: cost banner, message list, streaming, question view, scroll controls.
3. **Simplify StreamingMarkdownParser.parse()** — Extract per-block-type parsing into separate methods, keep parse() as thin dispatcher.

## Files Modified
- `Cloude/Cloude/UI/ConversationView+Components.swift`
- `Cloude/Cloude/UI/MainChatView.swift`
- `Cloude/Cloude/UI/StreamingMarkdownParser.swift`
