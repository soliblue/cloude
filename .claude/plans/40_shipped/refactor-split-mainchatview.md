---
title: "Split MainChatView.swift"
description: "Split 795-line MainChatView into 5 focused files for body, heartbeat, page indicator, and more."
created_at: 2026-02-06
tags: ["refactor", "ui"]
icon: scissors
build: 36
---


# Split MainChatView.swift {scissors}
## Changes
795 lines → 5 files:
- `MainChatView.swift` (407 lines) - body, headers, modifiers
- `MainChatView+Heartbeat.swift` (82 lines) - heartbeat window
- `MainChatView+PageIndicator.swift` (112 lines) - page dots
- `MainChatView+Messaging.swift` (120 lines) - send/stop/transcribe
- `MainChatView+Utilities.swift` (100 lines) - init, git, cleanup

## Test
- Swiping between windows works
- Heartbeat trigger button works
- Sending messages works (normal + queued)
- Page indicator dots show correct state (active, streaming)
- Window add/remove works
- Voice transcription works
