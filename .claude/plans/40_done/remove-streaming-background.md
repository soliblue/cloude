# Remove Streaming Message Background {minus.circle}
<!-- priority: 10 -->
<!-- tags: ui, streaming -->
<!-- build: 63 -->

> Removed pulsing accent-color background from messages during streaming.

## What
Remove the pulsing accent-color background that appeared behind messages while streaming.

## Changes
- `ChatView+Components.swift`: Removed `.background(Color.accentColor.opacity(pulse ? 0.06 : 0.02))` and associated `pulse` state + animation from both `StreamingOutput` and `StreamingInterleavedOutput`
