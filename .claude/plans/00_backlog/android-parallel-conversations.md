# Parallel Conversation Streaming (Android) {bubble.left.and.bubble.right}
<!-- priority: 12 -->
<!-- tags: android, conversations, architecture -->

> Stream multiple Claude Code sessions simultaneously so different windows can show independent conversations.

## Problem
Currently one CLI process per environment, one active conversation at a time. Switching conversations kills the previous session. Multi-window only provides different views (chat/files/git) into the same conversation.

## Desired Outcome
Multiple CLI processes running in parallel on the agent/relay, each tied to a window. WebSocket messages tagged with conversation/session IDs so responses route to the correct window. Each chat window can independently stream its own conversation.

**Requires changes to:** Agent/relay (process management), Android ConnectionManager (message multiplexing), WindowManager (conversation-window binding), ChatViewModel (per-window state). Should be implemented after the iOS version since the agent/relay changes are shared.
