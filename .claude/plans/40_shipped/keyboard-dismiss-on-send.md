---
title: "Keyboard dismiss + input clear on send"
description: "Fixed keyboard dismiss and input clearing on send to prevent laggy ghost state."
created_at: 2026-03-19
tags: ["input", "ui"]
icon: keyboard.chevron.compact.down
build: 96
---


# Keyboard dismiss + input clear on send {keyboard.chevron.compact.down}
Added `dismissKeyboard()` call in `sendMessage()`. Updated to dismiss keyboard first, then clear text/attachments on next run loop to prevent laggy multi-row ghost (TextField height not collapsing immediately when cleared while keyboard is still up). Also unified all clearing into one place - slash command early returns no longer clear `inputText` separately.

## Desired Outcome
1. Keyboard closes immediately after tapping send
2. Input field collapses to single row without lag (no ghost multi-row state)
3. Slash commands (/usage, /plans, /memories, /settings) still work correctly

**Files:** `Cloude/Cloude/UI/MainChatView+Messaging.swift`
