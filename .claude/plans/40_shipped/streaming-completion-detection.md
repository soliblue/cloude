---
title: "Streaming Completion Detection"
description: "Superseded by `10_next/unified-streaming.md`. Root cause #5 (view-dependent completion) and the duplicate message bug are directly solved by moving completion handling to the app level via `.streamingStarted` event. Remaining root causes (#1-4) are independent and can be addressed separately if still observed."
created_at: 2026-02-14
tags: ["streaming", "relay", "connection"]
icon: checkmark.circle.trianglebadge.exclamationmark
build: 71
---


# Streaming Completion Detection {checkmark.circle.trianglebadge.exclamationmark}
Long responses sometimes leave the iOS app in a "running" state even after the CLI has finished. The user has to manually hit stop.

## Root Causes (ranked by likelihood)

1. **Main thread starvation** — WebSocket receive loop gated by `@MainActor`, flood of `.output` messages delays processing of `.status(.idle)`
2. **Process termination as completion signal** — idle only sent when CLI process exits, not when model finishes responding
3. **Background/child processes keep pipes open** — `drainPipesAndComplete()` blocks on `readDataToEndOfFile()` if spawned processes inherit stdout/stderr
4. **No explicit "response complete" protocol message** — relies on `.status(.idle)` tied to process lifecycle, fragile when any edge case prevents broadcasting
5. **View-dependent completion logic** — `handleCompletion()` in `ConversationView.onChange(of: output?.isRunning)` only fires if the view is mounted

## Goals

- iOS app reliably detects when a response is complete, regardless of response length
- No false "still running" states after the CLI finishes

## Approach

1. **Decouple WebSocket receiving from `@MainActor`** — process incoming messages on a background queue, only hop to main for state updates
2. **Parse CLI `"result"` JSON event as completion signal** — send an explicit completion message when the model stream ends, don't wait for process exit
3. **Add safety timeout** — auto-mark runs as complete if no output received for N seconds (fallback)

## Files

- `Cloude/Cloude/Services/ConnectionManager.swift` — WebSocket receive loop, `ConversationOutput`
- `Cloude/Cloude/Services/ConnectionManager+API.swift` — `handleOutput`, `handleStatus`
- `Cloude/Cloude Agent/Services/ClaudeCodeRunner.swift` — process lifecycle, completion
- `Cloude/Cloude Agent/Services/ClaudeCodeRunner+Streaming.swift` — stream parsing, `drainPipesAndComplete()`
- `Cloude/Cloude Agent/Services/RunnerManager.swift` — `onComplete`, `onStatusChange`
- `Cloude/Cloude Agent/App/Cloude_AgentApp.swift` — status broadcast wiring
- `Cloude/CloudeShared/Sources/CloudeShared/Messages/ServerMessage.swift` — protocol messages
- `Cloude/Cloude/UI/ConversationView.swift` — `handleCompletion()` view dependency

## Related: Duplicate Message Display Bug

When the user leaves the chat view mid-stream and returns after it finishes, the same response appears twice — once as a saved message, once as stale streaming output. Refresh fixes it.

**Root cause:** `handleCompletion()` fires via `.onChange(of: output?.isRunning)` in `ConversationView` — if the view is unmounted when streaming ends, `onChange` never fires. `output.text` stays filled. When the view remounts, both the saved message (from `syncHistory`) and the stale `output.text` (in `streamingSection`) render simultaneously.

**Proposed fix:** Add `.onAppear` to `ConversationView` that checks for stale output and flushes it:
```swift
.onAppear {
    if let output = convOutput, !output.isRunning, !output.text.isEmpty {
        output.flushBuffer()  // drain CADisplayLink fully before finalizing
        handleCompletion()
    }
}
```

**Edge cases to handle:**
- Call `output.flushBuffer()` before checking, since the CADisplayLink drain might still be running (would finalize partial text)
- Double finalization is safe — `finalizeStreamingMessage` has a duplicate guard + `output.reset()` clears text, so second call bails on `guard !output.text.isEmpty`
- Brief flash possible if `syncHistory` also runs on foreground — minor visual glitch

**Bigger fix (if needed later):** Move completion handling out of the view entirely into `ConnectionManager+MessageHandler` when it receives `idle` status. View-independent, no lifecycle dependency. Bigger refactor though.

## Open Questions

- What timeout value for the safety fallback? (10s? 30s?)
- Should the `"result"` event trigger idle immediately, or should it coexist with process termination?
- Is batching/coalescing output chunks worth doing alongside this fix?
