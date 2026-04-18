---
title: "Heartbeat Icon Alignment Fix"
description: "Fixed heart icon sitting lower than other page indicator icons due to badge ZStack."
created_at: 2026-02-08
tags: ["ui", "heartbeat"]
icon: heart
build: 67
---


# Heartbeat Icon Alignment Fix {heart}
## Problem
Heart icon in the page indicator sat lower than other icons because the notification badge's ZStack affected layout height.

## Fix
Replaced `ZStack` with `.overlay` for the unread badge so it doesn't influence the icon's layout size.

## File
- `MainChatView+PageIndicator.swift`
