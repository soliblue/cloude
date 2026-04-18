---
title: "Queued Message: Long Press to Delete"
description: "Replaced swipe-to-delete on queued messages with long-press context menu for consistency."
created_at: 2026-03-03
tags: ["ui", "input"]
icon: hand.tap
build: 82
---


# Queued Message: Long Press to Delete {hand.tap}
## Problem
Swipe-to-delete on queued messages was causing interaction issues. Inconsistent with the rest of the app which uses long-press context menus.

## Fix
Replaced `SwipeToDeleteBubble` (custom drag gesture) with `QueuedBubble` (context menu with Delete option). Same pattern as copy/collapse on assistant messages.

## File
- `ConversationView+Components.swift` — replaced struct + updated call site
