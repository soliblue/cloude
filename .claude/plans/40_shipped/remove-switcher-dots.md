---
title: "Remove Switcher Dots"
description: "Removed dot indicators and unread tracking from the page indicator switcher."
created_at: 2026-03-15
tags: ["ui"]
icon: circle.slash
build: 86
---


# Remove Switcher Dots {circle.slash}
Removed the dot indicators below tab icons in the page indicator/switcher. They didn't work well, took unnecessary space, and didn't look good.

## Changes
- Removed all dot circles (unread + spacer dots) from switcher
- Removed `unreadWindowIds`, `markUnread()`, `markRead()`, `windowForConversation()` from WindowManager
- Removed `conversationOutputStarted` event and its sender
- Removed unread marking logic in CloudeApp and MainChatView

**Files:** `MainChatView+PageIndicator.swift`, `WindowManager.swift`, `CloudeApp.swift`, `MainChatView.swift`, `ConnectionEvent.swift`, `EnvironmentConnection+Handlers.swift`
