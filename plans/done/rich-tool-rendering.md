# Rich Tool Rendering — Phase 3: Live Subagent Tool Feed
<!-- priority: 10 -->
<!-- tags: tools -->
<!-- build: 56 -->

Phases 1 (shimmer) and 2 (result previews) are done.

## Goal

Task/Explore pills auto-expand during execution, showing child tools one by one:
- Nested tool calls arrive with `parent_tool_use_id` (already parsed)
- Auto-expand chevron during streaming
- Children get shimmer + result treatment
- Collapse when parent completes, show child count badge
- When children exceed 5, collapse older ones

## Files

- `Cloude Agent/Services/ClaudeCodeRunner+Streaming.swift` — forward child tool events
- `CloudeShared/Messages/ServerMessage.swift` — parent-child relationship in messages
- `Cloude/Cloude/Models/Conversation.swift` — maintain parent-child tool call tree
- `Cloude/Cloude/UI/ChatView+ToolPill.swift` — expand/collapse, nested children UI
