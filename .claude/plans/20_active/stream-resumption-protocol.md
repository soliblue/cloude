---
title: "Round: Deterministic stream resumption protocol"
description: "Replace client-side reconnect heuristics with per-session sequence numbers + server replay buffer. Collapse ConversationOutput lifecycle flags into a state enum."
created_at: 2026-04-19
tags: ["streaming", "agent", "relay", "protocol"]
icon: arrow.triangle.2.circlepath
---


# Round: Deterministic stream resumption protocol

## Context (from original plan ticket)

### Problem

The WebSocket protocol has no sequence numbers and no delivery tracking. Streaming events are fire-and-forget. When iOS reconnects mid-stream, the server cannot tell which chunks already arrived, so all reconciliation happens on the client via heuristics.

The "JSONL lags the live stream" gap is a symptom of this missing protocol primitive, not a separate problem.

#### Today's workarounds on the client

- `needsHistorySync` flag raised when a tool result arrives for a tool not in `output.toolCalls` (missed chunks inferred after the fact).
- Two-phase finalization: partial update, request missed response, sync history, then finalize.
- `pendingHistorySyncMetadata` dict stores run stats so they can be reapplied when JSONL eventually arrives.
- JSONL merge preserves client toolCalls if JSONL has fewer (JSONL lag recovery).
- `seedForReconnect()` restores `fullText` from a client snapshot so the live bubble does not blank on reconnect.

All of this exists because the protocol cannot answer "what did the client miss".

#### Server divergence bug

`requestMissedResponse` is a working `ResponseStore` lookup on the Mac agent and a literal no-op on the Linux relay (`handlers.js` has `break`). Same protocol, different semantics. Disconnecting mid-stream while attached to the Linux relay loses the output.

### Root cause

Two missing protocol primitives:

1. No per-event sequence number on `.output`, `.toolCall`, `.toolResult`, `.runStats`.
2. No server-side replay buffer keyed by session.

Plus one client anti-pattern that compounds both:

3. `ConversationOutput` carries `isRunning`, `isCompacting`, `needsHistorySync`, `skipped`, and uses `liveMessageId: UUID?` as a de-facto fifth state flag. Five booleans describing one lifecycle. Impossible combinations are reachable and the finalization code has to untangle them case by case.

### Direction

#### Protocol (CloudeShared)

Add a monotonic per-session `seq: Int` to every streaming server message (`.output`, `.toolCall`, `.toolResult`, `.runStats`).

Replace `requestMissedResponse(sessionId)` with `resumeFrom(sessionId, lastSeq)`.

`resumeFrom` replies with one of three shapes:
- a batch of events with `seq > lastSeq`
- an empty batch if the client is fully caught up
- a `historyOnly` signal if the server's buffer has rolled past `lastSeq` and the client should fall back to JSONL sync

#### Server (Mac agent and Linux relay)

Both implement the same in-memory ring buffer per session. Start with last 200 events or 60 seconds, whichever rolls first.

Stamp each outgoing event with `seq` as it is produced. Handle `resumeFrom` by replaying from the buffer.

Delete the Mac-specific `ResponseStore`. Both agents behave identically after this.

#### Client (iOS)

Track `lastSeenSeq` per session alongside `ConversationOutput`.

On reconnect, send `resumeFrom(sessionId, lastSeenSeq)` instead of today's mix of `requestMissedResponse`, `syncHistory`, and heuristic gap detection.

Collapse `ConversationOutput` lifecycle booleans into an explicit state enum:

```swift
enum StreamState {
    case idle
    case streaming(messageId: UUID)
    case compacting(messageId: UUID)
    case awaitingSync(messageId: UUID)
    case disconnected(snapshot: Snapshot)
    case finalized
}
```

Transitions become explicit; impossible combinations become unrepresentable. Finalization logic currently spread across `handleTurnCompleted`, `finalizeStreamingMessage`, `resetAfterLiveMessageHandoff`, `handleHistorySync`, and `pendingHistorySyncMetadata` collapses into transition handlers in one file.

`needsHistorySync` and the heuristic gap detection can be removed. Any seq gap is a deterministic signal.

### Non-goals

- Not changing the WebSocket transport itself.
- Not persisting the buffer across server restarts. A full restart still falls back to JSONL sync.
- Not adding per-client subscription routing. Broadcast-to-all stays for this ticket.

### Files to change

- `/Users/soli/Desktop/CODING/cloude/Cloude/CloudeShared/Sources/CloudeShared/Messages/ClientMessage.swift`
- `/Users/soli/Desktop/CODING/cloude/Cloude/CloudeShared/Sources/CloudeShared/Messages/ServerMessage.swift`
- `/Users/soli/Desktop/CODING/cloude/Cloude/CloudeShared/Sources/CloudeShared/Messages/ServerMessage+EncodingExt.swift`
- `/Users/soli/Desktop/CODING/cloude/Cloude/Cloude Agent/Services/RunnerManager.swift`
- `/Users/soli/Desktop/CODING/cloude/Cloude/Cloude Agent/Services/RunnerManager+Callbacks.swift`
- `/Users/soli/Desktop/CODING/cloude/Cloude/Cloude Agent/Services/ClaudeCodeRunner+EventHandling.swift`
- `/Users/soli/Desktop/CODING/cloude/Cloude/Cloude Agent/Services/ClaudeCodeRunner+Lifecycle.swift`
- `/Users/soli/Desktop/CODING/cloude/Cloude/Cloude Agent/Services/ResponseStore.swift` (delete)
- `/Users/soli/Desktop/CODING/cloude/linux-relay/runner.js`
- `/Users/soli/Desktop/CODING/cloude/linux-relay/handlers.js`
- `/Users/soli/Desktop/CODING/cloude/linux-relay/server.js`
- `/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Shared/Services/ConnectionManager+ConversationOutput.swift`
- `/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Shared/Services/EnvironmentConnection+Handlers.swift`
- `/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Shared/Services/EnvironmentConnection+MessageHandler.swift`
- `/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Features/Conversation/Utils/ConversationEventHandling.swift`
- `/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Features/Conversation/Utils/ConversationStore+Messaging.swift`

## Plan

### scope

In scope for this round:

- Baseline measurement of the client-side heuristic paths that exist today because the protocol cannot answer "what did the client miss". Target surfaces: `needsHistorySync` flag flips, `shouldSyncBeforeFinalize` two-phase path, `pendingHistorySyncMetadata` writes, `requestMissedResponse` sends, `seedForReconnect` calls, and the JSONL-lag branch in `replaceMessages` where `merged[i].toolCalls.count < existing.toolCalls.count`.
- Slice of the ticket landable in one sim round: CloudeShared protocol additions (`seq` on `.output`/`.toolCall`/`.toolResult`/`.runStats`, new `resumeFrom(sessionId, lastSeq)` with three reply shapes), Mac agent ring buffer + seq stamping in `RunnerManager+Callbacks.swift` and `ClaudeCodeRunner+EventHandling.swift`, Mac agent `resumeFrom` handler (replaces `ResponseStore` lookup in `AppDelegate+MessageHandling.swift`), iOS `lastSeenSeq` tracking in `ConversationOutput`, and replacement of the reconnect path in `EnvironmentConnection+Networking.swift`'s `checkForMissedResponse` with `resumeFrom`. The `StreamState` enum collapse in `ConversationOutput` is a follow-up round.

Out of scope for this round:

- Linux relay changes (`linux-relay/runner.js`, `linux-relay/handlers.js`, `linux-relay/server.js`). Sim tester runs iOS against the Mac agent path only. The relay no-op bug is a follow-up round once the Mac side is proven.
- `StreamState` enum migration across `ConnectionManager+ConversationOutput.swift`, `ConversationEventHandling.swift`, `ConversationStore+Messaging.swift`. Lifecycle-flag collapse is sequenced after the protocol primitive lands so both proofs do not collide.
- `ResponseStore.swift` deletion. Retain through this round, delete in the follow-up that also migrates the relay.

### reproduction

Minimal steps that exercise every heuristic the protocol replaces:

1. Open a conversation attached to the Mac agent environment in iOS Simulator.
2. Send `prompts/mixed-markdown-multi-tool.txt` to start a turn with tool calls.
3. As soon as at least one tool call appears executing, disconnect the environment (toggle off in the environment picker).
4. Wait ~1s so the Mac agent emits at least one `.toolResult` while the client is disconnected.
5. Reconnect the same environment.
6. Let the turn finish and observe the finalize path.

This single reproduction fires `handleDisconnect` (stores `interruptedSessions[sessionId]`), `checkForMissedResponse` on reauth, `handleMissedResponse` with `seedForReconnect` and `needsHistorySync = true`, then `handleTurnCompleted`'s `shouldSyncBeforeFinalize` branch with `pendingHistorySyncMetadata` write, then `handleHistorySync` reapplying metadata. On top of that, the `replaceMessages` JSONL-lag branch (preserve existing tool calls when JSONL has fewer) runs on most reconnects because the Mac agent's JSONL writer trails the live stream by one turn.

### scenarios

Use existing scenario at `/Users/soli/Desktop/CODING/cloude/.claude/agents/tester/scenarios/streaming-lifecycle-stress.md`. It already covers the three shapes this round needs (Message 1 clean turn baseline, Message 2 disconnect + reconnect mid-stream, Message 3 app-terminate + relaunch mid-stream). No extension required; the bug shape is exactly what the existing scenario stresses.

Additional assertion to apply per-message during measurement (does not require editing the scenario):

- For Message 1: all heuristic counters should be 0 (clean turn, no reconnect, no tool-result-before-call-sync).
- For Message 2: `seedForReconnect` fires exactly once, `needsHistorySync` flips to true exactly once, `requestMissedResponse` send count = 1, `shouldSyncBeforeFinalize` branch taken = 1, `pendingHistorySyncMetadata` write count >= 1, JSONL-lag merge branch hit count >= 1.
- For Message 3: same as Message 2 plus `handleReconnectRunning` path with `seedForReconnect` recovery fires once.

### target_metrics

Baseline must capture six counters per scenario message so after-state proves the heuristic paths stop firing:

1. `needsHistorySync_flip_count` - times `output.needsHistorySync = true` is set.
2. `requestMissedResponse_send_count` - times client sends `.requestMissedResponse`.
3. `seedForReconnect_call_count` - times `seedForReconnect` is invoked.
4. `shouldSyncBeforeFinalize_count` - times the two-phase finalize branch in `handleTurnCompleted` is taken.
5. `pendingHistorySyncMetadata_write_count` - times an entry is stashed in `pendingHistorySyncMetadata`.
6. `jsonl_lag_merge_count` - times `replaceMessages` hit the `merged[i].toolCalls.count < existing.toolCalls.count` branch.

After `resumeFrom(sessionId, lastSeq)` lands, counters 1, 2, 4, 5, and 6 must all read 0 across the full scenario because every gap is filled deterministically from the server buffer. Counter 3 (`seedForReconnect`) may still fire once per reconnect while the client replays the server-returned batch into the existing live bubble, but it stops being driven by `needsHistorySync`. Add a new counter 7 `resumeFrom_request_count` and 8 `resumeFrom_seq_gap_size` (events returned) to prove the new path carries the traffic.

### instrumentation

Logging-only edits. All counters are implemented as `AppLogger.connectionInfo` tagged strings so the tester can grep `heuristic_counter=` in `app-debug.log`. No behavior changes.

File 1: `/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Shared/Services/EnvironmentConnection+Handlers.swift`

- In `handleToolResult`, inside the existing `if !out.toolCalls.contains(where: { $0.toolId == toolId })` block, before `out.needsHistorySync = true` add:
  `AppLogger.connectionInfo("heuristic_counter=needsHistorySync_flip reason=tool_result_without_call convId=\(convId.uuidString) toolId=\(toolId)")`
- In `handleMissedResponse`, inside the `if output.isRunning` branch right before `output.seedForReconnect(...)` add:
  `AppLogger.connectionInfo("heuristic_counter=seedForReconnect reason=missed_response sessionId=\(sessionId) chars=\(text.count) tools=\(toolCalls.count)")`
- In `handleMissedResponse`, inside the same `if output.isRunning` branch right before `output.needsHistorySync = true` add:
  `AppLogger.connectionInfo("heuristic_counter=needsHistorySync_flip reason=missed_response_running sessionId=\(sessionId)")`

File 2: `/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Shared/Services/EnvironmentConnection+Networking.swift`

- In `checkForMissedResponse`, inside the for loop before `send(.requestMissedResponse(sessionId: sessionId))` add:
  `AppLogger.connectionInfo("heuristic_counter=requestMissedResponse_send sessionId=\(sessionId)")`

File 3: `/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Features/Conversation/Utils/ConversationEventHandling.swift`

- In `handleTurnCompleted`, immediately after the `let shouldSyncBeforeFinalize = ...` binding add:
  `AppLogger.connectionInfo("heuristic_counter=shouldSyncBeforeFinalize_eval convId=\(conversationId.uuidString) value=\(shouldSyncBeforeFinalize) needsHistorySync=\(needsHistorySync)")`
- Inside the `if shouldSyncBeforeFinalize, output.liveMessageId != nil, ...` branch, immediately before `conversationStore.pendingHistorySyncMetadata[conversation.id] = (...)` add:
  `AppLogger.connectionInfo("heuristic_counter=pendingHistorySyncMetadata_write phase=pre_sync convId=\(conversation.id.uuidString)")`
- In the post-finalize branch, before the second `conversationStore.pendingHistorySyncMetadata[updatedConversation.id] = (...)` write add:
  `AppLogger.connectionInfo("heuristic_counter=pendingHistorySyncMetadata_write phase=post_finalize convId=\(updatedConversation.id.uuidString)")`
- In `handleReconnectRunning`, before `output.seedForReconnect(lastMsg.text, toolCalls: lastMsg.toolCalls)` add:
  `AppLogger.connectionInfo("heuristic_counter=seedForReconnect reason=reconnect_running convId=\(conversationId.uuidString)")`

File 4: `/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Features/Conversation/Store/ConversationStore+Messages.swift`

- In `replaceMessages`, inside the `if let existing` block, inside the existing `if merged[i].toolCalls.count < existing.toolCalls.count` conditional, before the assignment add:
  `AppLogger.connectionInfo("heuristic_counter=jsonl_lag_merge convId=\(conversation.id.uuidString) jsonl_tools=\(merged[i].toolCalls.count) client_tools=\(existing.toolCalls.count)")`

Tester derives the six baseline counters by grepping `heuristic_counter=<name>` per scenario message. Counters 7 and 8 will be added in the solver round when `resumeFrom` lands; scoping them now locks the after-state assertion shape.

## Baseline

### Scenario: streaming-lifecycle-stress

**Invocation:** `/Users/soli/Desktop/CODING/cloude/.claude/agents/tester/scenarios/streaming-lifecycle-stress.md`

Steps run:
- Setup: Cleared `app-debug.log`. Opened new conversation via `cloude://conversation/new`. Set model to haiku via `cloude://conversation/model?value=haiku`. convId=`3FF99C17-5087-4269-A9DF-AD660CB30073`.
- Message 1: Sent `prompts/mixed-markdown-multi-tool.txt` at 07:53:29. Waited for normal completion (state=idle at 07:53:55).
- Message 2 (attempt 1, voided): Sent same prompt at 07:54:23. Turn completed before disconnect could fire (state=idle at 07:54:44, ~21s after send). Disconnect deep link arrived 8s after completion -- voided.
- Message 2 (actual): Sent same prompt at 07:55:34. Disconnect via `cloude://environment/disconnect?id=C10DE51D-5151-4551-8551-0000000C10DE` fired at 07:55:41 (7s after send, 2 tool calls in the new turn visible). Waited 40s. Reconnected via `cloude://environment/connect?id=C10DE51D-5151-4551-8551-0000000C10DE` at 07:56:21. Observed heuristic counter fire and log quiesce.
- Message 3: Sent `prompts/agent-group-completion.txt` at 07:57:44. Agent tool calls detected at 07:57:55. App terminated via `xcrun simctl terminate` at 07:58:00 (6s after send, 2 Agent + 2 Bash tool calls in progress). Waited 21s. Relaunched via `xcrun simctl launch` at 07:58:21. Observed post-relaunch state until log quiesced.

**Build:** commit=dc6635ed sim=E864DAC0-56D6-4B2D-BF16-5F6B5D5BD3B4 bundle=soli.Cloude build-timestamp=2026-04-19T07:53:00

**Metrics:**

| metric | value | unit | target | pass |
|---|---|---|---|---|
| chat.firstToken (msg1) | 5949 | ms | - | n/a |
| chat.complete (msg1) | 25925 | ms | - | n/a |
| chat.firstToken (msg2-actual) | 4344 | ms | - | n/a |
| chat.firstToken (msg3) | 9880 | ms | - | n/a |
| environment.auth (msg2 reconnect) | 25 | ms | - | n/a |
| environment.auth (msg3 relaunch) | 228 | ms | - | n/a |

**Heuristic counters per message (baseline):**

| counter | msg1 | msg1 expected | msg2 | msg2 expected | msg3 | msg3 expected |
|---|---|---|---|---|---|---|
| needsHistorySync_flip_count | 0 | 0 | 0 | 1 | 0 | 1 |
| requestMissedResponse_send_count | 0 | 0 | 1 | 1 | 0 | 1 |
| seedForReconnect_call_count | 0 | 0 | 0 | 1 | 0 | 1 |
| shouldSyncBeforeFinalize_count (value=true) | 0 | 0 | 0 | 1 | 0 | 1 |
| pendingHistorySyncMetadata_write_count | 0 | 0 | 0 | >=1 | 0 | >=1 |
| jsonl_lag_merge_count | 0 | 0 | 0 | >=1 | 0 | >=1 |

**Assertions:**

- Message 1 all-six-counters=0: PASS - `shouldSyncBeforeFinalize_eval value=false needsHistorySync=false` logged at 07:53:55; no other heuristic counters fired; `finalize live message update` logged cleanly; state=idle reached.
- Message 2 seedForReconnect fires exactly once: FAIL - counter reads 0. `handleMissedResponse` received `missed response chars=2580 tools=9` (full turn completed at Mac agent during the 40s disconnect window) but `output.isRunning` was false (cleared by `handleDisconnect` at 07:55:41), so the `else` branch ran instead of the seeding branch.
- Message 2 needsHistorySync flip=1: FAIL - counter reads 0, same cause as above.
- Message 2 requestMissedResponse_send=1: PASS - fired once at 07:56:21 for sessionId=fff88852.
- Message 2 shouldSyncBeforeFinalize=1: FAIL - counter reads 0. `shouldSyncBeforeFinalize_eval` never logged for Message 2 window; `handleTurnCompleted` never reached on the reconnect path.
- Message 2 pendingHistorySyncMetadata_write>=1: FAIL - counter reads 0.
- Message 2 jsonl_lag_merge>=1: FAIL - counter reads 0. No JSONL sync triggered.
- Message 2 response rendered correctly: PARTIAL - no `finalize live message update` logged after reconnect; live bubble state not confirmed from visible UI (scrolled to prompt).
- Message 3 requestMissedResponse_send=1: FAIL - counter reads 0. Server pushed `missed response` proactively at relaunch (07:58:22.829) without client sending `requestMissedResponse`. The relaunch cold-boot path does not call `checkForMissedResponse`; the Mac agent delivers the response on auth.
- Message 3 seedForReconnect reason=reconnect_running fires once: FAIL - counter reads 0. App booted fresh with no in-memory `output.isRunning` state; `handleReconnectRunning` path not taken.
- Message 3 needsHistorySync flip=1: FAIL - counter reads 0.
- Message 3 shouldSyncBeforeFinalize=1: FAIL - counter reads 0. `shouldSyncBeforeFinalize_eval` not logged for Message 3 window.
- Message 3 pendingHistorySyncMetadata_write>=1: FAIL - counter reads 0.
- Message 3 jsonl_lag_merge>=1: FAIL - counter reads 0.
- no stuck live bubble after completion: FAIL (msg2, msg3) - no `finalize live message update` after reconnect or relaunch; state=running persisted.
- no duplicated markdown sections: n/a - finalization incomplete, content not confirmed rendered.
- no duplicated tool groups: n/a.
- correct final ordering of text, tool groups, completion state: FAIL - finalization did not complete for Message 2 or Message 3.

**Notable logs:**

1. `sessionId=fff88852-dbf7-4f15-b552-b36dc8d57e60` is reused for all three messages (Messages 1, 2, and 3) within the same conversation. The Mac agent's `ResponseStore` keyed by this ID returned Message 2's completed response when the reconnect sent `requestMissedResponse` -- `missed response chars=2580 tools=9` at 07:56:21.753, confirmed by `run stats durationMs=21816`. The Mac agent finished the full turn during the 40s disconnect window.

2. Message 2 disconnect timing: `handleDisconnect` fired at 07:55:41 when the turn was ~7s in with 2 tool calls (Bash + Read) received, Read result arriving. By reconnect at 07:56:21 (40s gap), the Mac agent had completed all 9 tool calls and the full response. `handleMissedResponse` received a complete turn but the `output.isRunning` guard was false, so `output.reset()` ran instead of `seedForReconnect`. No `finalize live message update` followed reconnect.

3. Message 3 relaunch: app booted at 07:58:22.504. The Mac agent pushed `missed response sessionId=fff88852 chars=1172 tools=6` at 07:58:22.829 -- 325ms after boot, with no prior `requestMissedResponse_send` from the client. This confirms the Mac agent's ResponseStore delivers the result proactively on auth for the relaunch path, bypassing the client's `checkForMissedResponse` flow entirely. `chars=1172 tools=6` represents the 3 Agent + 3 Bash sub-calls that completed by 07:58:21 (the third Agent was still running at termination per 07:57:58 tool results); `run stats durationMs=22025` shows the Mac agent finished ~22s into the turn.

4. `shouldSyncBeforeFinalize_eval` logged exactly twice: once for Message 1 (value=false, 07:53:55) and once for Message 2 attempt 1 which completed without disconnect (value=false, 07:54:44). Never logged for Message 2-actual or Message 3, confirming `handleTurnCompleted` is never reached on the reconnect and relaunch paths.

5. The `finalize live message update` logged for Message 1 (liveId=38C69C76, chars=2534, tools=9) and Message 2 attempt 1 (liveId=9F1A1856, chars=2318, tools=9), both clean completions. Never logged for Message 2-actual or Message 3.

6. `jsonl_lag_merge` never fired across all messages. Consistent with the prior run: the JSONL-lag branch in `replaceMessages` is unreachable when `handleHistorySync` is never called, which in turn requires `handleTurnCompleted` to set `shouldSyncBeforeFinalize`.

**Artifacts:**

- `/Users/soli/Desktop/CODING/cloude/.claude/agents/tester/output/stress2-msg1-log-slice-20260419.txt`
- `/Users/soli/Desktop/CODING/cloude/.claude/agents/tester/output/stress2-msg2-log-slice-20260419.txt`
- `/Users/soli/Desktop/CODING/cloude/.claude/agents/tester/output/stress2-msg3-log-slice-20260419.txt`
- `/Users/soli/Desktop/CODING/cloude/.claude/agents/tester/output/simulator-20260419-075253.png` (initial app state before log clear)
- `/Users/soli/Desktop/CODING/cloude/.claude/agents/tester/output/simulator-20260419-075304.png` (new conversation opened)
- `/Users/soli/Desktop/CODING/cloude/.claude/agents/tester/output/simulator-20260419-075335.png` (Message 1 streaming)
- `/Users/soli/Desktop/CODING/cloude/.claude/agents/tester/output/simulator-20260419-075410.png` (Message 1 completed)
- `/Users/soli/Desktop/CODING/cloude/.claude/agents/tester/output/simulator-20260419-075441.png` (Message 2 tool calls streaming)
- `/Users/soli/Desktop/CODING/cloude/.claude/agents/tester/output/simulator-20260419-075552.png` (disconnected state, Message 2)
- `/Users/soli/Desktop/CODING/cloude/.claude/agents/tester/output/simulator-20260419-075729.png` (after reconnect, Message 2 settled)
- `/Users/soli/Desktop/CODING/cloude/.claude/agents/tester/output/simulator-20260419-075852.png` (after relaunch, Message 3 settled)

**Run notes:**

- Message 2 required two send attempts. The first attempt (07:54:23) completed its full turn in ~21s before a disconnect could be triggered via deep link. A second send at 07:55:34 succeeded in disconnecting at 07:55:41 (7s after send, 2 new tool calls detected).
- The `shouldSyncBeforeFinalize_eval` instrumentation is confirmed active (fired for both clean completions). The absence of counters 1, 3, 4, 5, 6 for Messages 2 and 3 is structural -- `handleTurnCompleted` is never reached on reconnect or relaunch paths.
- Message 2 reconnect `requestMissedResponse_send` fired (PASS), confirming `checkForMissedResponse` runs on the `connectEnvironment` path. Message 3 relaunch did NOT fire `requestMissedResponse_send` -- the Mac agent delivers `missedResponse` proactively on auth for cold boot, diverging from the reconnect path.
- The session ID `fff88852-dbf7-4f15-b552-b36dc8d57e60` persists across all messages in the conversation, meaning the Mac agent's `ResponseStore` lookup for `requestMissedResponse` returns the most recent completed session -- in Message 2's case, the just-completed turn (correct), but in Message 3's case the same session ID yields what was running at termination.
- Results are consistent with the prior baseline run (2026-04-19T07:25-07:43). The heuristic paths that the round targets (counters 1, 3, 4, 5, 6) are confirmed not firing because the `output.isRunning` guard in `handleMissedResponse` is unreachable after `handleDisconnect` clears the running state.

## Hypothesis

**Chosen option: C (different, sharper hypothesis)**

### Analysis

The baseline does not show "heuristics overactively reconciling." It shows `handleMissedResponse` in `EnvironmentConnection+Handlers.swift` falling into its `else` branch at line 144 and calling `output.reset()` silently, on both disconnect/reconnect (Message 2) and cold-boot relaunch (Message 3). The `if output.isRunning` guard at line 137 is structurally unreachable: `handleDisconnect` already ran `output.reset()` + set `isRunning = false` at lines 74-75 of `EnvironmentConnection+MessageHandler.swift` during the disconnect window, and on cold boot `isRunning` is false by definition before the proactive `.missedResponse` from the Mac agent arrives.

Every heuristic counter the plan predicted (`seedForReconnect`, `needsHistorySync`, `shouldSyncBeforeFinalize`, `pendingHistorySyncMetadata`, `jsonl_lag_merge`) is downstream of that unreachable branch, which is why all five read 0 and no `finalize live message update` logs. The fix is not the full `seq`+`resumeFrom`+ring-buffer protocol; it is making the `handleMissedResponse` seeding path reachable when the client has an `interruptedSessions` or `pendingMissedResponseTargets` entry for the session, regardless of `isRunning`.

In that case the returned `text` + `toolCalls` are authoritative state for the interrupted message and should be seeded into the live bubble (or a reconstructed one using `interruptedMessageId`), then finalized via the existing `turnCompleted` path. The full protocol redesign can wait until this smaller invariant is proven and the three baseline scenarios finalize cleanly.

### Allowed files

- `/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Shared/Services/EnvironmentConnection+Handlers.swift` - rewrite `handleMissedResponse` seeding branch to gate on `interruptedConvId != nil`, not `output.isRunning`; restore `liveMessageId`, seed text/toolCalls, set `isRunning = true`, let `handleStatus` / `turnCompleted` finalize normally.
- `/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Shared/Services/EnvironmentConnection+MessageHandler.swift` - stop calling `output.reset()` inside `handleDisconnect`; preserve `fullText`, `toolCalls`, `liveMessageId` so reconnect has something to seed into, only clear `isRunning`.
- `/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Shared/Services/EnvironmentConnection+Networking.swift` - verify `checkForMissedResponse` still fires on the reconnect path; if `handleAuthResult` now races with a proactive server push on cold boot, dedupe via `pendingMissedResponseTargets` guard - no new logic, one condition.

### Target metrics (after-run)

All three scenario messages must log exactly one `finalize live message update` per turn. Message 2 and Message 3 must log `heuristic_counter=seedForReconnect reason=missed_response` exactly once each (counter 3 goes from 0 to 1, proving the seeding branch is now reachable). `state=idle` must be reached after reconnect and after relaunch without a stuck live bubble. Counters 1, 2, 4, 5, 6 may remain 0 - they are downstream of history sync which this fix does not require. Introduce no new protocol fields.

### Note on the original plan

The full `seq` + `resumeFrom` + server ring-buffer redesign described in the original plan ticket is still a valid follow-up. Once this narrower fix lands and reconnect finalizes deterministically on the Mac path, the protocol primitive can be added to make replay gap-free rather than best-effort. But the immediate blocker in the observed baseline is the unreachable seeding branch, not the missing `seq` field.
