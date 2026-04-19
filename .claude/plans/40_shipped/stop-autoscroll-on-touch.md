---
title: "Stop Auto-Scroll on Touch"
description: "Stop auto-scrolling to bottom when user touches or drags the chat during streaming."
created_at: 2026-03-01
tags: ["ui", "streaming"]
icon: hand.tap
build: 82
---


# Stop Auto-Scroll on Touch
When the user touches or drags the chat scroll view during streaming, auto-scroll should stop so they can read earlier content without being yanked to the bottom.

## Changes
- `ConversationView+Components.swift`: Added `userHasScrolled` state
  - Set `true` on tap or drag gesture
  - Prevents `scrollTo(bottom)` during `currentOutput` changes
  - Reset to `false` on: new user message, conversation change, scroll-to-bottom button tap
