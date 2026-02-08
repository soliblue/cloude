# Tool Streaming Data {waveform.path}
<!-- priority: 3 -->
<!-- tags: agent, tools, streaming -->

> Capture richer tool data from the CLI stream that we're currently ignoring. The CLI emits `stream_event` deltas with incremental tool input as it's generated, and structured `tool_use_result` fields with typed metadata — we flatten everything into plain strings.

## What We're Missing

### During Execution (stream_event deltas)
- `content_block_delta` with `input_json_delta` streams the tool input **token by token** as the model generates it
- We could show the command/path/pattern building up in real time instead of just "Executing"
- Currently we wait for the full `type: "assistant"` message to get the complete input

### In Results (tool_use_result)
- **Bash**: `stdout`, `stderr`, `interrupted`, `isImage` — we could show stderr separately, flag interrupted commands
- **Read**: `filePath`, `content`, `numLines`, `startLine`, `totalLines` — we could show "read 50 of 533 lines" context
- **Edit/Write**: likely has structured fields too
- Currently all flattened into a single `resultOutput` string

## Approach
1. Parse `stream_event` `content_block_start` (type: tool_use) + `content_block_delta` (input_json_delta) to stream tool input incrementally
2. Parse `tool_use_result` structured fields on the agent side and forward richer metadata to iOS
3. Update `ToolCall` model to carry optional structured result metadata
4. Update `ToolDetailSheet` to use structured data when available

## Files
- `Cloude/Cloude Agent/Services/ClaudeCodeRunner+Streaming.swift` — stream parsing
- `Cloude/Cloude Agent/Services/RunnerEvent.swift` — event types
- `Cloude/Cloude/Models/Conversation.swift` — ToolCall model
- `Cloude/Cloude/UI/ToolDetailSheet.swift` — detail sheet rendering
- `Cloude/Cloude/UI/ChatView+ToolPill.swift` — inline pill (streaming input preview)
