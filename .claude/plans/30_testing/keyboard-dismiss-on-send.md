# Keyboard dismisses on message send
<!-- build: 96 -->

Added `dismissKeyboard()` call at the end of `sendMessage()` so the keyboard closes when a message is sent.

## Desired Outcome
Keyboard closes immediately after tapping send.

**Files:** `Cloude/Cloude/UI/MainChatView+Messaging.swift`
