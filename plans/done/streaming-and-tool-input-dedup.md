# Streaming + Tool Input Dedup

## Status: active

## Tasks

### 1. Unify content-block handling in processStreamLines
- Lines 34-49 handle `stream_event` wrapping `content_block_start` / `content_block_delta`
- Lines 52-65 handle top-level `content_block_start` / `content_block_delta`
- Both do the same thing — merge into single handler

### 2. Extract shared tool input parsing into CloudeShared
- `extractToolInputString` in ClaudeCodeRunner+Streaming.swift (line 324) — takes parsed `[String: Any]`
- `extractToolDetail` in ConnectionManager+API.swift (line 5) — takes raw JSON string, parses it, extracts + truncates
- Create `ToolInputExtractor.swift` in CloudeShared with unified implementation
- Update both call sites
