---
title: "Android Message Info Sheet"
description: "Move message metadata to a long-press info sheet."
created_at: 2026-04-05
tags: ["android", "messages", "ux"]
build: 125
icon: info.circle
---
# Android Message Info Sheet


## Desired Outcome
Long-press context menu on messages includes an "Info" option that opens a bottom sheet showing: timestamp, model used, duration, cost, character count, and tool call count. Reduces visual clutter by removing inline footer stats.

## iOS Reference Architecture

### Components
- `MessageBubble+ActionMenu.swift` - MessageInfoSheet with formatted rows

### Android implementation notes
- Add "Info" option to existing `DropdownMenu` on message long-press
- Create `MessageInfoSheet` as `ModalBottomSheet`
- Display: formatted timestamp, model name, duration (if available), cost, text length, tool call count
- Remove or simplify the inline cost/model label from `MessageBubble`

**Files (iOS reference):** MessageBubble+ActionMenu.swift
