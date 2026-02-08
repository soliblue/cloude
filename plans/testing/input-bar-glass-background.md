# Input Bar Glass Background {textfield}
<!-- priority: 2 -->
<!-- tags: ui, input-bar -->

> Make the input bar background more translucent/liquid glass instead of heavy `.ultraThinMaterial`.

## Problem

The bottom bar (input field + page indicator) uses `.ultraThinMaterial` on three layers — the container VStack, the text field capsule, and suggestion pills. When the keyboard opens and the bar flies to the top, the background is too opaque — you can't see chat text behind it. Feels heavy, not minimal.

## Approach

- Make the container background (MainChatView.swift:110) more transparent — either lighter material or remove it entirely
- Keep the text field capsule with a subtle glass look but lighter
- Goal: liquid glass feel where chat text bleeds through behind the bar
- Consider `Color(.secondarySystemBackground)` or lower-opacity material for the capsule
- Test with keyboard open (bar at top) to ensure readability over chat content

## Files
- `Cloude/Cloude/UI/MainChatView.swift` (container background, line 110)
- `Cloude/Cloude/UI/GlobalInputBar.swift` (text field background line 303, suggestions line 150)
