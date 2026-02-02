# History Sync (Hybrid, Single-Conversation Refresh)

## Goal
Use Mac CLI history as the single source of truth for a conversation when the user triggers refresh, while keeping all conversations stored locally on iOS.

## Assumptions Tested (from actual CLI history)
- CLI history is JSONL in `~/.claude/projects/<project-path>/<session-id>.jsonl`.
- `user` and `assistant` entries include a `timestamp` field with ISO8601 + fractional seconds (e.g. `2026-01-31T11:30:52.198Z`).
- `assistant` entries include `tool_use` blocks with `id`, `name`, and `input`.
- User prompts are stored as plain text in `message.content` even when they reference an image file path.
- Image bytes appear only in `tool_result` entries (user messages with `content` arrays containing `type: image`).
- There are non-message entries (system, file-history-snapshot, tool_result in user content arrays) that should be ignored by the iOS history view.

(Validated by inspecting files under `~/.claude/projects/-Users-soli-Desktop-CODING-cloude/`.)

## Proposed Behavior
- On refresh, replace the entire conversation message list with the CLI history for that session.
- Preserve tool calls exactly as recorded by the CLI.
- Use CLI timestamps for `ChatMessage.timestamp` (not `Date()`), so ordering and display match the source of truth.
- Keep `pendingMessages` untouched so queued items survive a refresh.

## Files to Change

### iOS
1. `Cloude/Cloude/Models/Conversation.swift`
   - Add a `ChatMessage` initializer that accepts an explicit `timestamp`.

2. `Cloude/Cloude/App/CloudeApp.swift`
   - In `onHistorySync`, map `HistoryMessage.timestamp` into `ChatMessage` using the new initializer.

3. `Cloude/Cloude/Models/ProjectStore+Conversation.swift` (optional but recommended)
   - In `replaceMessages`, set `lastMessageAt` to the max message timestamp so list ordering reflects CLI history.

### macOS Agent
- No changes expected (HistoryService already parses timestamps and tool calls).

## Implementation Steps
1. Extend `ChatMessage` with a timestamped initializer (keep current init unchanged for normal usage).
2. Update `onHistorySync` to create `ChatMessage(isUser:text:timestamp:toolCalls:)`.
3. (Optional) Update `replaceMessages` to set `lastMessageAt` based on the last CLI message timestamp.

## Edge Cases
- If session history file is missing, keep local messages and surface the existing error UI.
- If user sent a message while offline and it never reached the CLI, a full replace will drop that local message. (Current app has no offline send queue, so this is acceptable for now; we can add a guard later if needed.)
- Image prompts: the CLI stores only the text prompt; the actual image is in a `tool_result` entry. Full replace will drop iOS image thumbnails unless we parse tool_result images and reattach them.
- Tool results are not stored in history as assistant messages; they will not appear in iOS unless we add support for user tool_result blocks.

## Testing Plan (manual)
1. Start a conversation, run a few prompts, trigger tools (Bash/Read).
2. Force a refresh using the existing pull-to-refresh/sync action.
3. Verify:
   - Message order matches CLI timestamps in JSONL.
   - Tool calls appear in assistant messages.
   - `pendingMessages` (if any) remain queued after refresh.

## Success Criteria
- Refresh replaces the conversation with CLI history without errors.
- Timestamps reflect CLI history (not local device time).
- Tool calls are preserved and visible.
