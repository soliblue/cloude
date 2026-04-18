---
title: "Fix Chat Auto-Scroll Direction"
description: "Chat scrolls to the beginning of the conversation instead of the bottom when new messages arrive."
created_at: 2026-03-29
tags: ["android", "ui", "bug"]
build: 120
icon: arrow.down.to.line
---
# Fix Chat Auto-Scroll Direction {arrow.down.to.line}


## Problem
When sending a message or receiving streaming output, the LazyColumn scrolls to the start of the conversation instead of the latest message. The `animateScrollToItem` call in ChatScreen may be targeting the wrong index or firing at the wrong time.

## Desired Outcome
Chat always scrolls to the newest message, matching iOS behavior. Auto-scroll on send, on streaming text updates, and on new assistant messages.

**Files:** `UI/chat/ChatScreen.kt`
