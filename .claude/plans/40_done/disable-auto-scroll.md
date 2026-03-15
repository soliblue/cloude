# Disable Auto-Scroll on Streaming Response
<!-- build: 86 -->

Auto-scroll during streaming output was annoying - content kept jumping while trying to read.

## Change
Removed the auto-scroll trigger from `currentOutput` onChange in `ConversationView+Components.swift`. Now only scrolls to bottom when a new user message is sent. Scroll-to-bottom button still available for manual jump.

**Files:** `Cloude/Cloude/UI/ConversationView+Components.swift`
