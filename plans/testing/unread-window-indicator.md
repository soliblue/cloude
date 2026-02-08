# Unread Window Notification Indicator

## Problem
When a window has unread messages (including streaming content with unread parts), there's no visual indicator on the window dot in the switcher. Users miss new information in other windows.

## Solution
Add a small accent-colored circle at the top of window dots in the page indicator/switcher when the window has unread content. This signals "new information you haven't seen."

## Scope
- Track unread state per window (new messages arrived while not viewing that window)
- Show small accent dot on the window indicator button
- Clear unread state when user switches to that window
- Also mark as unread during streaming if the user isn't viewing that window

## Files
- `MainChatView+PageIndicator.swift` — window dot rendering
- Possibly `ConnectionManager.swift` or model layer for unread tracking
