---
title: "Window Tab Re-render Fix"
description: "Reduce unnecessary re-renders in window tab bar and page indicator during streaming."
created_at: 2026-03-26
tags: ["performance", "swiftui"]
icon: bolt
build: 115
---


# Window Tab Re-render Fix
## What Changed
- Extracted `WindowTabBar` as standalone struct (was extension method on MainChatView). Takes only primitive values (WindowType, Bool, closure) so SwiftUI skips re-renders when values unchanged.
- Removed `toolCalls` and `runStats` propagation from ConversationOutput to ConnectionManager. These fired on every tool call (~50+ per turn) but only ObservedMessageBubble needs them (observes ConversationOutput directly).
- `isRunning`, `isCompacting`, `text`, `newSessionId`, `skipped` still propagate (needed by input bar, page indicator).

## What to Test
- Run a conversation and check debug overlay for WindowTabBar render frequency (should be much less than before)
- Verify streaming still works (text appears, tool pills animate, stop button shows)
- Verify tab switching (chat/terminal/files/git) still works
- Verify page indicator still pulses for streaming windows
- Verify connection/disconnect still disables non-chat tabs
