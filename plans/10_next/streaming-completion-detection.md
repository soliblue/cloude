# Streaming Completion Detection

**Tags:** reliability, bug

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

## Open Questions

- What timeout value for the safety fallback? (10s? 30s?)
- Should the `"result"` event trigger idle immediately, or should it coexist with process termination?
- Is batching/coalescing output chunks worth doing alongside this fix?
