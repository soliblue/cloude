---
title: "Remove Streaming Message Background"
description: "Removed pulsing accent-color background from messages during streaming."
created_at: 2026-02-08
tags: ["ui", "streaming"]
icon: minus.circle
build: 62
---


# Remove Streaming Message Background {minus.circle}
## What
Remove the pulsing accent-color background that appeared behind messages while streaming.

## Changes
- `ChatView+Components.swift`: Removed `.background(Color.accentColor.opacity(pulse ? 0.06 : 0.02))` and associated `pulse` state + animation from both `StreamingOutput` and `StreamingInterleavedOutput`
