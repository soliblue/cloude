# Disable Auto-Scroll on Streaming Response {arrow.down.to.line}
<!-- priority: 10 -->
<!-- tags: ui, streaming -->
<!-- build: 86 -->

> Removed auto-scroll during streaming so content stops jumping while reading.

Auto-scroll during streaming output was annoying - content kept jumping while trying to read.

## Change
Removed the auto-scroll trigger from `currentOutput` onChange in `ConversationView+Components.swift`. Now only scrolls to bottom when a new user message is sent. Scroll-to-bottom button still available for manual jump.

**Files:** `Cloude/Cloude/UI/ConversationView+Components.swift`
