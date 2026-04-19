---
title: "Tool Shimmer Animation"
description: "Added shimmer gradient animation on tool pills during execution that fades when the tool result arrives."
created_at: 2026-02-06
tags: ["tool-pill", "ui"]
icon: sparkle
build: 33
---


# Tool Shimmer Animation
## Done

Phase 1 of rich tool rendering — shimmer animation on tool pills during execution.

- Tool pills shimmer (gradient sweep) while executing
- Animation stops with fade when tool result arrives
- `ToolCallState` enum: `.executing` / `.complete`
- `ShimmerOverlay` view with `CADisplayLink`-synced phase animation
- State tracked via `tool_result` messages from CLI stream

## Files Modified

- `Cloude/Models/Conversation.swift` — `ToolCallState` enum, `state` on `ToolCall`
- `Cloude Agent/Services/ClaudeCodeRunner+Streaming.swift` — parse `tool_result` from user messages
- `Cloude Agent/Services/RunnerEvent.swift` — `.toolResult` event
- `Cloude Agent/Services/RunnerManager.swift` — relay tool result
- `CloudeShared/Messages/ServerMessage.swift` — `.toolResult` message type
- `Cloude/Services/ConnectionManager+API.swift` — handle `.toolResult`, set state
- `Cloude/UI/ChatView+MessageBubble.swift` — `ShimmerOverlay`, animation logic
