---
title: "Conversation Search"
description: "Added conversation search sheet accessible from bottom switcher bar, searching across names, directories, and message content."
created_at: 2026-02-09
tags: ["ui"]
icon: magnifyingglass
build: 69
---


# Conversation Search {magnifyingglass}
## What
- Search icon in bottom switcher bar now opens a conversation search sheet
- Search across conversation names, working directories, and message content
- Results grouped by project directory, sorted by recency
- Message content matches show snippet context

## Changes
- `MainChatView+PageIndicator.swift`: Fixed vertical alignment of heartbeat + search buttons (added VStack + frame(height: 39) to match window indicator structure)
- `MainChatView.swift`: Added `showConversationSearch` state + sheet
- `ConversationSearchSheet.swift`: New search sheet with `.searchable` field, grouped results, message snippet preview
