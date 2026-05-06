---
title: "Parallel Conversation Streaming (Android)"
description: "Stream multiple Claude Code sessions simultaneously so different windows can show independent conversations."
created_at: 2026-04-02
tags: ["android", "conversations", "architecture"]
build: 125
icon: bubble.left.and.bubble.right
---
# Parallel Conversation Streaming (Android)


## Problem
Currently one CLI process per environment, one active conversation at a time. Switching conversations kills the previous session. Multi-window only provides different views (chat/files/git) into the same conversation.

## Desired Outcome
Multiple CLI processes running in parallel on the agent/relay, each tied to a window. WebSocket messages tagged with conversation/session IDs so responses route to the correct window. Each chat window can independently stream its own conversation.

**Requires changes to:** Agent/relay (process management), Android ConnectionManager (message multiplexing), WindowManager (conversation-window binding), ChatViewModel (per-window state). Should be implemented after the iOS version since the agent/relay changes are shared.

## Blocked features
- **Fork to new tab**: Forking a conversation should open the fork in a separate tab so the user can continue both chats independently. Currently fork replaces the active conversation because all windows share one ChatViewModel.
