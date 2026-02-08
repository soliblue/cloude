# Remove Streaming Message Background

**Status:** testing
**Tags:** ui, chat

## What
Remove the pulsing accent-color background that appeared behind messages while streaming.

## Changes
- `ChatView+Components.swift`: Removed `.background(Color.accentColor.opacity(pulse ? 0.06 : 0.02))` and associated `pulse` state + animation from both `StreamingOutput` and `StreamingInterleavedOutput`
