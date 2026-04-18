---
title: "Page Indicator Conversation Names"
description: "Show each conversation name above its page indicator icon so the bottom switcher is easier to scan."
created_at: 2026-03-28
tags: ["ui", "conversations"]
icon: textformat.size.smaller
build: 120
---


# Page Indicator Conversation Names
Added conversation name text above the icon in page indicators at the bottom of the chat view. Names use `DS.Text.xs`, single line truncated, same color/weight as the icon.

## Test
- Verify conversation names appear above icons
- Check truncation with long names
- Verify "New Chat" shows for unnamed conversations
- Check active vs inactive styling matches
