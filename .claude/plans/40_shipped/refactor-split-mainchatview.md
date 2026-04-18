# Split MainChatView.swift {scissors}
<!-- priority: 10 -->
<!-- tags: refactor, ui -->
<!-- build: 56 -->

> Split 795-line MainChatView into 5 focused files for body, heartbeat, page indicator, and more.

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
