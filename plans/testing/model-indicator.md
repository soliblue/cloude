# Show Model Name Per Response

## Status: Testing

## Summary
Show the model name (e.g. "Opus", "Sonnet", "Haiku") in the run stats bar below each assistant message. Now works for all cases: explicit model selection, default model, and conversation refresh.

## Changes

### Live streaming fix (ClaudeCodeRunner+Streaming.swift)
- Capture model from CLI `init` message into `activeModel` when no explicit model was specified
- Previously only worked when `--model` was passed explicitly; now the CLI's `init` event (which always includes the model) is used as fallback

### History sync fix (HistoryMessage.swift, HistoryService.swift, CloudeApp.swift)
- Added `model: String?` field to `HistoryMessage`
- `HistoryService` extracts `message.model` from assistant entries in the JSONL history files
- Model is preserved through message merging (consecutive assistant messages)
- `CloudeApp` passes model through when converting `HistoryMessage` → `ChatMessage`

### Display (already existed)
- `RunStatsView` shows model with icon: crown (Opus), hare (Sonnet), leaf (Haiku)
- `ChatMessage` already had `model: String?` field

## Test Cases
- Default model run → should show "Opus" (or whatever the default is)
- Explicit model selection → should show selected model
- Refresh/pull-down on conversation → model labels should persist
- Open an old conversation from session list → model should show
- Mixed model conversation (switch mid-chat) → each message shows its own model
