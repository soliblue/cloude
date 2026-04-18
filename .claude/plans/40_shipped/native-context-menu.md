---
title: "Native Context Menu for Messages"
description: "Replace the custom long-press overlay on messages with the native iOS context menu for copy, text selection, and collapse actions."
created_at: 2026-03-26
tags: ["ui", "messages"]
icon: hand.tap
build: 113
---


# Native Context Menu for Messages
Replaced the custom long-press overlay (glass morphism horizontal menu with manual positioning) with native iOS `.contextMenu`. Actions: Copy, Select Text, Collapse/Expand.

## Test
- [ ] Long-press a user message: Copy and Select Text appear
- [ ] Long-press an assistant message: Copy, Select Text, and Collapse appear
- [ ] Long-press a collapsed message: shows Expand instead of Collapse
- [ ] Copy works and shows toast
- [ ] Select Text opens the text selection sheet
- [ ] Collapse/Expand toggles correctly
- [ ] Long-press on live (streaming) messages does nothing
- [ ] Messages with interactive widgets have no context menu conflict
