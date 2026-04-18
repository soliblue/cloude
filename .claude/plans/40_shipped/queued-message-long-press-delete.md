# Queued Message: Long Press to Delete {hand.tap}
<!-- priority: 10 -->
<!-- tags: ui, input -->
<!-- build: 82 -->

> Replaced swipe-to-delete on queued messages with long-press context menu for consistency.

## Problem
Swipe-to-delete on queued messages was causing interaction issues. Inconsistent with the rest of the app which uses long-press context menus.

## Fix
Replaced `SwipeToDeleteBubble` (custom drag gesture) with `QueuedBubble` (context menu with Delete option). Same pattern as copy/collapse on assistant messages.

## File
- `ConversationView+Components.swift` — replaced struct + updated call site
