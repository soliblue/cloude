---
title: "Streaming Reliability"
description: "Umbrella plan for streaming correctness, persistence, running state, and recovery across app lifecycle events."
created_at: 2026-03-28
tags: ["streaming", "reliability", "messages"]
icon: waveform.path.ecg
build: 120
---


# Streaming Reliability {waveform.path.ecg}
Track and fix streaming issues systematically. Keep concrete shipped fixes in `30_testing/`, and keep unresolved cross-cutting work here.

## Data Flow

```
Claude CLI stdout
  -> ClaudeCodeRunner.processStreamLines (Mac agent)
    -> content_block_delta -> onOutput?(deltaText) [live streaming]
    -> assistant message -> fill gaps via deltaTextCount when needed
  -> WebSocket ServerMessage.output(text)
    -> EnvironmentConnection.handleOutput (iOS)
      -> ConversationOutput.appendText(chunk) -> fullText += chunk
        -> CADisplayLink drains fullText -> text at 300 chars/sec
          -> ObservedMessageBubble reads output.text as liveText
  -> Status idle
    -> flushBuffer() -> text = fullText
    -> isRunning = false
    -> finalizeStreamingMessage()
      -> msg.text = output.text -> output.reset()
```

## Fixed Work Now Tracked In Testing

- Duplicate text: see `plans/30_testing/fix-duplicate-text.md`
- Running state for tool-first responses: see `plans/30_testing/streaming-running-state.md`
- Tool pill completion state: see `plans/30_testing/fix-tool-pill-active-state.md`
- Scroll behavior change: see `plans/30_testing/remove-auto-scroll.md`

## Remaining Reliability Work

### Persist partial output on app lifecycle change

Live message text is only finalized at stream completion. If the app is backgrounded or killed mid-stream, the persisted message can be empty.

Recommended approach:
- Flush `output.text` into the live `ChatMessage` on `.background` and `.inactive`
- Clean up empty ghost messages on launch
- Avoid per-chunk persistence unless lifecycle flush proves insufficient

### Verify tab switch and disconnect recovery

Still needs verification for:
- tab switch during streaming
- background and foreground during streaming
- disconnect and reconnect while streaming
- force-quit during streaming

## Verification Checklist

- [ ] Send a message and verify no duplicate text
- [ ] Send a message and verify no truncated text
- [ ] Trigger tool-only responses and verify running state is correct
- [ ] Switch tabs during streaming and verify final message completion
- [ ] Background app during streaming and verify recovery
- [ ] Force-quit mid-stream and verify no empty ghost bubble remains
- [ ] Disconnect network during streaming and verify recovery behavior
- [ ] Verify tool calls display correctly and complete visually
