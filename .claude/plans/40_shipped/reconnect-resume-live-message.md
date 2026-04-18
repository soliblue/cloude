---
title: "Reconnect Resume Live Message"
description: "Resume streaming into the same message bubble after app disconnect/reconnect instead of splitting into two bubbles."
created_at: 2026-03-31
tags: ["streaming"]
icon: arrow.triangle.2.circlepath
build: 122
---


# Reconnect Resume Live Message {arrow.triangle.2.circlepath}
## Problem

When the app disconnects mid-stream (background, network drop) and reconnects while the server is still running, the partial message was saved as interrupted and a new empty live message was created below it. This split one assistant turn into two bubbles with a status bar between them.

## Solution

Three changes:

1. **`seedForReconnect`** on `ConversationOutput` - seeds the text/tool buffer with existing message content so new deltas append seamlessly.

2. **`resumeOrInsertLiveMessage`** on `ConversationStore` - shared helper that checks if the last message is an interrupted assistant message. If so, reuses it as the live message (clearing the orange interrupted state). Otherwise inserts a new live message as before.

3. **Three call sites updated** to use the helper:
   - `.streamingStarted` event handler
   - `.historySync` event handler (uses last assistant message from server history, no `wasInterrupted` check since server messages don't carry that flag)
   - `ConversationView.onAppear` fallback

## Files

- `Cloude/Cloude/Services/ConnectionManager+ConversationOutput.swift` - added `seedForReconnect`
- `Cloude/Cloude/Models/ConversationStore+Messages.swift` - added `resumeOrInsertLiveMessage`
- `Cloude/Cloude/App/CloudeApp+EventHandling.swift` - updated `.streamingStarted` and `.historySync`
- `Cloude/Cloude/UI/ConversationView.swift` - updated `.onAppear`
