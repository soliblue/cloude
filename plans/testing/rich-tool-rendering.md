# Rich Tool Rendering — Remaining Phases

Phase 1 (shimmer animation) is done and shipped. These phases remain:

## Phase 2: Result Previews

Show brief result summary as a second line on completed tool pills:
- `↳ 241 lines` for Read
- `↳ Build Succeeded` for xcodebuild
- `↳ 12 matches in 4 files` for Grep
- `↳ ✓` for Edit/Write success
- `↳ ✗ old_string not found` for Edit errors (red tint)

Requires: capturing result content from `tool_result` stream blocks (currently only extracting `tool_use_id`, ignoring content).

## Phase 3: Live Subagent Tool Feed

Task/Explore pills auto-expand during execution, showing child tools one by one:
- Nested tool calls arrive with `parent_tool_use_id` (already parsed)
- Auto-expand chevron during streaming
- Children get shimmer + result treatment
- Collapse when parent completes, show child count badge
- When children exceed 5, collapse older ones

## Files

- `Cloude Agent/Services/ClaudeCodeRunner+Streaming.swift` — extract result content
- `CloudeShared/Messages/ServerMessage.swift` — add result summary to `.toolResult`
- `Cloude/Models/Conversation.swift` — populate `resultSummary`
- `Cloude/UI/ChatView+MessageBubble.swift` — result subtitle, live children
