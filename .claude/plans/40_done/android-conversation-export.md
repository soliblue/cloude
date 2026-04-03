# Android Conversation Export {square.and.arrow.up}
<!-- priority: 14 -->
<!-- tags: android, conversations -->

> Export current conversation as formatted markdown to clipboard or share sheet.

## Context

iOS can export the active conversation as a markdown string: user messages as `**User**: ...`, assistant messages with tool call summaries. Copied to clipboard with one tap.

## Scope

- Add "Export" option to conversation toolbar or context menu
- Format all messages as markdown (user role prefix, assistant content, tool call summaries)
- Copy to clipboard with toast confirmation
- Optionally offer Android share sheet for sending to other apps

## Implementation

- Iterate `ConversationStore.messages`, format by role
- Tool calls rendered as `> Tool: name (status)` blocks
- Use `ClipboardManager` for copy, `Intent.ACTION_SEND` for share
