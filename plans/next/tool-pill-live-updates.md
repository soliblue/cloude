# Tool Pill Live Updates

## Goal
Show live updates from tool calls as subtitle text below tool pills, with consistent design.

## Current State
- Subtitle UI (↳ resultSummary) is commented out in `ChatView+ToolPill.swift`
- The `resultSummary` property exists on `ToolCall` and is populated by the server
- Same pattern was used in `ToolDetailSheet.swift` for child tools

## Requirements
- Show tool result summary below the pill after completion
- Show live progress/status during execution (not just after)
- Consistent design with the rest of the chat UI
- Should not cause layout jank or message movement during streaming
- Truncation and overflow handling

## Files
- `Cloude/Cloude/UI/ChatView+ToolPill.swift` — main pill view (subtitle commented out)
- `Cloude/Cloude/UI/ToolDetailSheet.swift` — child tool list (has similar pattern)
- `Cloude/CloudeShared/Sources/CloudeShared/Messages/ServerMessage.swift` — ToolCall model
