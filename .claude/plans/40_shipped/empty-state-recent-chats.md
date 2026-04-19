---
title: "Empty State: More Recent Chats + See All"
description: "Increased recent chats from 3 to 5 in empty state and added \"See all\" button to open search."
created_at: 2026-03-15
tags: ["ui"]
icon: list.bullet
build: 86
---


# Empty State: More Recent Chats + See All
Show 5 recent conversations (up from 3) in the empty window state, with a subtle "See all >" button that opens the conversation search sheet. Content pushed up for better visual balance.

## Changes
- `ConversationView+EmptyState.swift`: prefix 3→5, added `onSeeAll` callback, "See all >" button top-right of list, extra Spacer at bottom to push content up
- `ConversationView+Components.swift`: added `onSeeAllConversations` property to `ChatMessageList`
- `ConversationView.swift`: added `onSeeAllConversations` property, threaded to ChatMessageList
- `MainChatView+Windows.swift`: wired `onSeeAllConversations` to `showConversationSearch = true`

## Test
- Open a new/empty window
- Verify 5 recent chats show (if available)
- Verify "See all >" button appears top-right of the list
- Tap "See all" opens the conversation search sheet
- Content should sit higher than before (not perfectly centered)
