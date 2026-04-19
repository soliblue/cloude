---
title: "Keyboard Dismiss Animation"
description: "Animated input bar transition when keyboard dismisses instead of snapping instantly."
created_at: 2026-03-13
tags: ["ui", "input"]
icon: keyboard.chevron.compact.down
build: 86
---


# Keyboard Dismiss Animation
## Changes
- `MainChatView.swift`: Wrap `isKeyboardVisible` state changes in `withAnimation` using the keyboard notification's duration/curve
- Added `keyboardAnimation(from:)` helper that extracts iOS keyboard animation parameters

## Test
- Open keyboard by tapping input bar
- Dismiss keyboard (swipe down or tap outside)
- Input bar should smoothly animate back to bottom instead of snapping
