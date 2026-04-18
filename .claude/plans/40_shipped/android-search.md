---
title: "Android Conversation Search"
description: "Search across conversations by name, working directory, and message text."
created_at: 2026-03-29
tags: ["android", "search"]
icon: magnifyingglass
build: 120
---
# Android Conversation Search {magnifyingglass}
<!-- status: done -->


## Implementation

- `ConversationListSheet.kt` - SearchBar composable with magnifying glass icon, BasicTextField, clear button
- Filters conversations by name, working directory, and message text (case-insensitive)
- `matchSnippet()` extracts 80-char preview with 30 chars before + 50 chars after match, with ellipsis
- ConversationRow shows optional match snippet in muted text below conversation name
- Empty state shows "No conversations found" when search has no results

### Not yet matching iOS
- iOS groups results by working directory with section headers
- iOS searches tool call content too

**Files (iOS reference):** MainChatView+SearchSheet.swift (+Components)
**Files (Android):** ConversationListSheet.kt
