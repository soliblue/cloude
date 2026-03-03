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

## Codex Review

**Findings (highest risk first)**

1. High: The plan needs an explicit correlation strategy for partial tool input events, or you'll get duplicate/misaligned tool pills. Current flow creates tool calls only from final `assistant` `tool_use` blocks, then appends directly. If you also emit from `content_block_start`/`input_json_delta`, you need a single source-of-truth keyed by `toolId` and "upsert", not append.
2. High: Scope is larger than listed files; protocol changes must be end-to-end. `toolResult` is currently hard-coded to `(summary, output)` in shared wire types (`ServerMessage.swift:17`) and broadcast as such (`Cloude_AgentApp.swift:134`). Coordinated updates needed in runner callbacks, manager callbacks, server message encode/decode, and client handlers.
3. High: UI won't reliably refresh for streaming updates to an existing tool call. `ToolCall.input` is immutable (`let`), and markdown cache invalidation only watches `toolCalls.count`. Input/result metadata updates on existing items may not trigger expected recompute/render behavior.
4. Medium: Per-token delta forwarding can cause UI thrash and battery/perf cost. `input_json_delta` may arrive at token cadence; pushing every chunk to SwiftUI/live activity would be noisy. Add throttling/coalescing (e.g., 50-100ms) before emitting to UI.
5. Medium: Persistence/history path is currently string-only. `StoredToolCall` only stores flattened `input`. Without a migration plan, structured metadata disappears on reconnect/missed-response/history restore.
6. Medium: Output size and safety need explicit policy for structured fields. Current output is truncated to 5000 chars. Structured stdout/stderr/file content may be much larger; define caps, truncation markers, and redaction behavior.

**Suggested improvements**
1. Add protocol primitives first: `toolCallStarted`, `toolCallUpdated` (partial input), `toolCallCompleted`, `toolResultMetadata`. Keep existing `toolResult(summary, output)` for backward compatibility during rollout.
2. Change `ToolCall` to support mutable streaming fields (or replace-on-update with a stable `toolId` upsert path).
3. Add a parser state machine in runner keyed by content-block index/tool id; finalize once full `assistant.tool_use` arrives.
4. Throttle partial-input UI updates and only show "nice" previews when JSON is parseable; otherwise show raw partial text safely.
5. Extend persistence (`StoredToolCall`) with optional structured metadata and default decoding for older records.
6. Implement per-tool rendering adapters in `ToolDetailSheet` with graceful fallback to plain text.

**Missing test coverage**
1. Stream parser tests for `content_block_start` + multiple `input_json_delta` chunks + final `assistant.tool_use`.
2. Upsert behavior tests: no duplicate `ToolCall` entries for same `toolId`.
3. Backward compatibility tests for old/new `ServerMessage.toolResult` payloads.
4. UI update tests for in-place tool call metadata changes (not just count changes).
5. Persistence decode/encode migration tests for `StoredToolCall`.
