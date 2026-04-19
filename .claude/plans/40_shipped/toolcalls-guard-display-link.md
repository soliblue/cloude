---
title: "Guard toolCalls + Display Link Rate"
description: "Prevent unnecessary @Published firings on toolCalls and reduce display link to 30fps."
created_at: 2026-04-01
tags: ["streaming"]
icon: gauge.with.dots.needle.33percent
build: 122
---


# Guard toolCalls + Display Link Rate
## Changes
- `completeTopLevelExecutingTools()` and `completeExecutingTools()` now early-return when no executing tools exist
- Display link frame rate reduced from 60fps to 30fps for text draining
- Removed unused `windowManager` @ObservedObject from ConversationSearchSheet

## Verify

Outcome: text streaming feels smooth at 30fps drain rate, tool call streaming works correctly with guarded mutations, search sheet opens without errors.

Test:
1. Send a long markdown prompt and verify smooth text reveal (no stuttering or chunky appearance)
2. Send a prompt that triggers tool calls (e.g. "read the README") and verify tools display correctly with state transitions
3. Open conversation search sheet and verify it loads and filters correctly
4. Check FPS stays at 59-61 during streaming
