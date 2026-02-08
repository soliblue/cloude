# Per-Message Refresh {arrow.clockwise.circle}
<!-- priority: 2 -->
<!-- tags: ui, chat, ux -->

> Add a refresh button on assistant response bubbles to re-generate individual messages.

## Problem

The only way to refresh is the header button which refreshes the entire conversation. No way to surgically say "this one response was bad, redo it."

## Approach

- Add a small refresh icon on each assistant message bubble (near run stats — duration/cost)
- On tap: if the message has an ID, re-generate just that specific message
- If no ID (or it's the last message), remove it and refresh the conversation
- Keep the existing header refresh button too — both coexist
- Consider showing on tap/long-press only to avoid clutter, or always visible but subtle

## Files
- `Cloude/Cloude/UI/ChatView+MessageBubble.swift` (add refresh icon to assistant bubbles)
- `Cloude/Cloude/Services/ConnectionManager.swift` (per-message refresh command)
- `Cloude Agent/Services/ClaudeCodeRunner.swift` (handle per-message re-generation)
