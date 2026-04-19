---
title: "Send Button Hit Area + Pill Style"
description: "Redesigned send/action button as a filled circle pill with generous hit area and animated state transitions."
created_at: 2026-02-07
tags: ["input"]
icon: circle.fill
build: 43
---


# Send Button Hit Area + Pill Style
Redesigned the send/action button as a prominent pill:
- **Filled circle** with accent background + white icon when active (can send or stop)
- **Transparent** with dimmed accent icon when inactive (nothing to send)
- Shared style across all states: send (paperplane), queue (clock), stop (stop)
- 36pt circle with 8pt inset expansion for generous hit area
- Animated transitions between states

**Changed**: `GlobalInputBar.swift` — extracted `actionButtonLabel` and `actionButtonIcon` shared across all button states.
