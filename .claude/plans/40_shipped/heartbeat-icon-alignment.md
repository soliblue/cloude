# Heartbeat Icon Alignment Fix {heart}
<!-- priority: 10 -->
<!-- tags: ui, heartbeat -->

> Fixed heart icon sitting lower than other page indicator icons due to badge ZStack.

## Problem
Heart icon in the page indicator sat lower than other icons because the notification badge's ZStack affected layout height.

## Fix
Replaced `ZStack` with `.overlay` for the unread badge so it doesn't influence the icon's layout size.

## File
- `MainChatView+PageIndicator.swift`
