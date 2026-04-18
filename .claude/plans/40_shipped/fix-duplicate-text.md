# Fix Duplicate Text in Streaming Output
<!-- build: 120 -->

Removed text re-emission from `handleAssistantMessage` in the Mac agent. Text was being sent twice: once via `content_block_delta` streaming events and again when the full `assistant` message arrived. The `.contains()` dedup check was fragile due to extra `\n\n` separators.

## Test
- Send a message and verify no duplicated text in the response
- Check multi-turn conversations for any missing text
- Verify tool calls still display correctly
