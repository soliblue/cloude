---
title: "Message Count in Conversation Picker"
description: "Added message count display next to relative time in the recent conversations list."
created_at: 2026-02-06
tags: ["conversations", "messages"]
icon: number
build: 33
---


# Message Count in Conversation Picker {number}
Show message count next to relative time in the recent conversations list on the window edit form.

## Files
- `Cloude/Cloude/UI/WindowEditForm.swift`

## Notes
- Added `X msgs` below the relative time in a trailing-aligned VStack
- The "See All" view (WindowConversationPicker) already had message counts
