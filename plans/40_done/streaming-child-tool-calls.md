# Streaming Child Tool Calls Bug

## Problem
Nested/child tool calls (e.g., Explorer spawning multiple sub-tool-calls) render correctly when loading a saved conversation but NOT during real-time streaming.

## Root Cause
Two different rendering paths:

- **Saved messages** use `ToolGroupView` which computes a `toolHierarchy` — matching children to parents via `parentToolId` and passing them to `InlineToolPill(toolCall:children:)`
- **Streaming output** uses `StreamingInterleavedOutput` which iterated top-level tools and passed them to `InlineToolPill(toolCall:)` with NO children

## Fix
In `StreamingInterleavedOutput` (ChatView+Components.swift), extract child tool calls from the full `toolCalls` array and pass them to each parent pill — same logic as `ToolGroupView`.

## Files Changed
- `Cloude/Cloude/UI/ChatView+Components.swift` — added child extraction in streaming tools segment

## Test
1. Start a conversation, ask Claude to use the Task/Explorer tool
2. Watch the tool pills during streaming — child tools should appear as badge count on the parent pill
3. Refresh the conversation — should look identical to streaming
