# Message Deduplication Plan

## Problem

When restarting the iOS app, sometimes the same message appears twice. This happens because:

1. `addMessage` appends blindly without checking for duplicates
2. `onMissedResponse` falls back to `addMessage` when it can't match `interruptedConvId`/`interruptedMsgId`
3. `onDisconnect` saves partial messages with client-generated UUIDs
4. History sync uses `replaceMessages` which works, but reconnect flows can still cause duplicates

## Key Insight: Server UUIDs

Claude CLI provides a `uuid` field on every message in:
- **Streaming output**: `{"type":"assistant", "uuid":"...", ...}` - arrives at END of message
- **JSONL history files**: Same UUID is persisted

**A message with a server UUID is complete by definition.** Messages without server UUIDs are in-flight/partial.

## Solution

### Core Principle
Don't persist partial messages. Only messages with server UUIDs are "real".

### iOS-Side Tracking
Each conversation tracks:
- `lastServerUUID: String?` - the last complete message UUID we have

### On Disconnect Mid-Stream
- Don't save the partial message
- Just show a loading/streaming indicator
- Remember the conversation was interrupted (optional, for UX)

### On Reconnect
1. iOS sends to agent: "conversation Y, last UUID I have is X"
2. Agent checks:
   - If still streaming → tell iOS to wait, show loading indicator
   - If finished → send any messages after UUID X
3. iOS adds new messages (all have UUIDs, no duplicates possible)

### History Sync (Refresh)
Instead of `replaceMessages`:
1. Get history from server (all messages have UUIDs)
2. Remove any local messages WITHOUT a server UUID (incomplete partials)
3. Add any messages from server that we don't have (match by UUID)
4. Order by timestamp

### Streaming Display
- While streaming: show live text (not persisted)
- On completion: receive UUID, NOW persist the message
- On disconnect mid-stream: show loading indicator, wait for sync

## Changes Required

### CloudeShared
- Add `serverUUID: String?` to `HistoryMessage`
- Add `serverUUID: String?` to whatever message type iOS uses (or `ChatMessage`)

### Mac Agent - ClaudeCodeRunner+Streaming.swift
- Extract `uuid` from streaming JSON when `type == "assistant"`
- Pass it through to iOS when message completes

### Mac Agent - HistoryService.swift
- Already extracts UUID internally, just need to include it in `HistoryMessage`

### Mac Agent - WebSocketServer
- New message type: `syncRequest(conversationId, lastUUID)`
- Response: either "still streaming" or list of new messages

### iOS - ChatMessage
- Add `serverUUID: String?` field

### iOS - ProjectStore+Conversation.swift
- Replace `replaceMessages` with `mergeMessages` that dedupes by UUID
- `addMessage` should set serverUUID when available

### iOS - ConnectionManager
- On reconnect: send sync request with lastUUID
- Handle "still streaming" response (show loading)
- Handle new messages response (merge them)

### iOS - CloudeApp.swift
- Remove `onDisconnect` partial message saving
- Remove `onMissedResponse` complexity
- Simplify to UUID-based sync

## Benefits
- No duplicate messages ever (UUID is unique)
- No partial messages persisted
- Clean reconnect flow
- Simpler code (remove `wasInterrupted`, `interruptedSession`, etc.)
- Works across devices (if same session viewed from multiple places)

## Migration
Existing messages won't have serverUUIDs. Options:
1. Treat them as complete (grandfather in)
2. On first sync, replace all with server history
3. Add serverUUID to existing messages by matching content+timestamp with history

Option 2 is cleanest - one-time refresh gets everything in sync.
