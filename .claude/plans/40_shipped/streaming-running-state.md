---
title: "Streaming Running State Fix"
description: "Mark conversations as running on tool calls as well as text output so streaming state stays correct across reconnects."
created_at: 2026-03-26
tags: ["streaming", "connection"]
icon: power
build: 113
---


# Streaming Running State Fix
Cherry-picked from fix/reconnect-streaming-state. Marks conversation as running on tool calls (not just text output) and extracts ensureRunning helper.

## Test
- [ ] Send a message that triggers tool calls: conversation shows as running immediately
- [ ] Tool-only responses (no text before tools) still show streaming UI
- [ ] Returning to foreground after backgrounding during streaming shows correct state
- [ ] Idle state still clears running state properly
