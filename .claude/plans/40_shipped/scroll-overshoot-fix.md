---
title: "Scroll Overshoot Fix in Long Conversations"
description: "Fixed scroll overshooting past content in long conversations by adding delayed correction scrolls."
created_at: 2026-03-16
tags: ["ui", "streaming"]
icon: arrow.down.to.line
build: 86
---


# Scroll Overshoot Fix in Long Conversations
Sending a message in a long conversation sometimes scrolled to an empty screen. Root cause: `LazyVStack` hasn't calculated full content height when `scrollTo` fires, so it overshoots past content.

Fix: added 50ms delay before first scroll + correction scroll 300ms later in `ConversationView+Components.swift`.

## Test
- Open a long conversation (50+ messages)
- Send a message
- Should scroll to show your message, not blank space
- Try multiple times — bug was intermittent
