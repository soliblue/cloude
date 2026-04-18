---
title: "Fix: empty chat input above keyboard"
description: "Wrap the empty conversation view in a scroll view so keyboard avoidance keeps the input anchored correctly."
created_at: 2026-04-02
tags: ["input", "ui"]
icon: keyboard.chevron.compact.down
build: 125
---


# Fix: empty chat input above keyboard

Wrapped EmptyConversationView in a ScrollView so SwiftUI keyboard avoidance works correctly in new empty conversations. Without a ScrollView, the keyboard safe area adjustment pushed the input field above the keyboard with a gap.
