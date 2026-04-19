---
title: "Disable Auto-Scroll on Streaming Response"
description: "Removed auto-scroll during streaming so content stops jumping while reading."
created_at: 2026-03-15
tags: ["ui", "streaming"]
icon: arrow.down.to.line
build: 86
---


# Disable Auto-Scroll on Streaming Response
Auto-scroll during streaming output was annoying - content kept jumping while trying to read.

## Change
Removed the auto-scroll trigger from `currentOutput` onChange in `ConversationView+Components.swift`. Now only scrolls to bottom when a new user message is sent. Scroll-to-bottom button still available for manual jump.

**Files:** `Cloude/Cloude/UI/ConversationView+Components.swift`
