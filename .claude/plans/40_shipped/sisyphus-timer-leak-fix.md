---
title: "Sisyphus Timer Leak Fix"
description: "Fixed loading animation running at 2x speed on subsequent messages by replacing stacking Timers with TimelineView."
created_at: 2026-03-04
tags: ["ui"]
icon: timer
build: 82
---


# Sisyphus Timer Leak Fix
## What
Loading animation ran 2x speed on the 2nd message because `Timer.scheduledTimer` was never invalidated — each `onAppear` stacked a new timer.

## Fix
Replaced `Timer.scheduledTimer` + `@State frameIndex` with `TimelineView(.periodic(...))` which is SwiftUI-native and automatically starts/stops with the view lifecycle. Frame index computed from elapsed time.

## Test
- Send a message, watch the boulder animation
- Send a 2nd message — animation should run at the same speed as the first
