# Persist Tool Results Through History Reload {clock.arrow.circlepath}
<!-- priority: 6 -->
<!-- tags: agent, relay -->

> Tool pills lose their result details after refreshing because HistoryService skips tool_result entries in JSONL history.

## Problem
Tool pills lose their result details (output, summary) after refreshing a conversation. The JSONL history files contain `tool_result` entries in user messages, but `HistoryService` skips them entirely - it only parses user messages with plain string `content`, not the array-of-objects format that contains `tool_result` items.

## Data Flow
1. **JSONL has it**: User messages contain `{"type": "tool_result", "tool_use_id": "toolu_xxx", "content": "Found 29 files..."}`
2. **HistoryService drops it**: Only extracts `tool_use` from assistant messages, never reads `tool_result` from user messages
3. **StoredToolCall lacks it**: No field for result content
4. **iOS never gets it**: Converts `StoredToolCall` -> `ToolCall` with nil `resultOutput`/`resultSummary`

## Solution

### Mac Agent / Linux Relay (`HistoryService.swift` + relay equivalent)
- Parse user messages with array content format (not just plain string)
- Extract `tool_result` entries, index by `tool_use_id`
- After building `StoredToolCall` list, match each `toolId` to its result and attach the content

### Shared Model (`StoredToolCall` in CloudeShared)
- Add `resultContent: String?` field

### iOS (`EnvironmentConnection+Handlers.swift`)
- Pass `resultContent` through when converting `StoredToolCall` -> `ToolCall.resultOutput`

### Linux Relay
- Mirror the same parsing logic for the relay's history handler

## Files
- `Cloude/Cloude Agent/Services/HistoryService.swift` - parse tool_result from user messages
- `Cloude/CloudeShared/Sources/CloudeShared/Models/HistoryMessage.swift` - add resultContent to StoredToolCall
- `Cloude/Cloude/Services/EnvironmentConnection+Handlers.swift` - pass through on conversion
- `linux-relay/` - mirror changes
