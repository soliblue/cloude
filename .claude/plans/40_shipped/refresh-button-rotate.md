---
title: "Refresh Button Rotate Animation"
description: "Added rotate animation to the refresh button in GlobalInputBar."
created_at: 2026-03-14
tags: ["ui", "input"]
icon: arrow.clockwise
build: 86
---


# Refresh Button Rotate Animation
Ad-hoc request. Added `.symbolEffect(.rotate)` to the refresh button in GlobalInputBar.

## Done
- [x] Added `refreshRotateTrigger` state to GlobalInputBar
- [x] Trigger rotation on refresh button tap
- [x] Applied `.symbolEffect(.rotate, value:)` to action button image
- [x] Deployed Build 86 to iPhone
