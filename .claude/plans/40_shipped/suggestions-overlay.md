---
title: "Suggestions Float as Overlay"
description: "Float slash-command, file, and history suggestions above the input bar so they stop pushing the message list around."
created_at: 2026-03-27
tags: ["ui", "input"]
icon: capsule
build: 115
---


# Suggestions Float as Overlay
Suggestion pills (slash commands, file suggestions, history) now float above the input bar as an overlay instead of being in a VStack that pushes the message list up.

## Test
- [ ] Type `/` and verify suggestions appear above input bar without shifting messages
- [ ] Type `@` with a file query and verify file suggestions float correctly
- [ ] Tap a suggestion pill and verify it works (hit testing)
- [ ] Horizontal scroll through suggestions works
- [ ] Suggestions have a visible backdrop (not transparent between pills)
- [ ] Dismiss suggestions and verify no layout artifacts
