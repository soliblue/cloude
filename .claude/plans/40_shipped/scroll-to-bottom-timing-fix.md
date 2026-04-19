---
title: "Scroll to bottom timing fix"
description: "Fixed scroll-to-bottom to reliably include newly sent message by triggering on message ID instead of count."
created_at: 2026-03-19
tags: ["ui", "streaming"]
icon: arrow.down.circle
build: 96
---


# Scroll to bottom timing fix
Changed scroll trigger from `messages.count` to `messages.last?.id` and added `await Task.yield()` so the scroll fires after SwiftUI has laid out the new message row.

## Desired Outcome
Scroll to bottom reliably includes the newly sent message row.

**Files:** `Cloude/Cloude/UI/ConversationView+Components.swift`
