# Message Disappears on Send

Last assistant message briefly disappears when the user sends a new message, then reappears on refresh.

## Root Cause

In `ConversationStore+Operations.swift`, `replaceMessages()` replaces local messages entirely with the server's list (`$0.messages = merged`). When an assistant message was just finalized locally but hasn't received a `serverUUID` yet (the `.messageUUID` event arrives separately), the server's history doesn't include it. The merge logic can't match it (no UUID, position mismatch), so it gets dropped.

Flow:
1. Assistant finishes streaming → `finalizeStreamingMessage` adds message with `serverUUID: nil`
2. User sends new message → triggers `replaceMessages` with server history
3. Server history doesn't include the latest assistant message yet
4. `$0.messages = merged` overwrites local list → message gone
5. On refresh → full history includes it with proper UUID → reappears

## Fix

After building `merged` from server messages, append any trailing local-only messages (no `serverUUID` and not matched by the server response) so they survive until the next sync assigns them proper IDs.

## Files
- `Cloude/Cloude/Models/ConversationStore+Operations.swift` — `replaceMessages()` around line 171
