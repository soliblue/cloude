---
title: "Fix: Tool call positions offset after message save / reconnect"
description: "Fixed tool pills appearing at wrong positions after message save or mid-stream reconnect by adjusting for trim offset and clamping positions."
created_at: 2026-02-07
tags: ["tool-pill", "streaming"]
icon: mappin.and.ellipse
build: 43
---


# Fix: Tool call positions offset after message save / reconnect {mappin.and.ellipse}
## Problem
Tool pills appear at wrong positions (off by ~2 chars, cutting into words) in two scenarios:
1. After a streaming message is saved — positions shift because leading whitespace is trimmed
2. After closing/reopening app mid-stream — positions are based on full server text but iOS only has partial text

## Root Causes

### Bug 1: Trimming offset on save
`ConversationView.handleCompletion()` trims the text with `.trimmingCharacters(in: .whitespacesAndNewlines)` but passes tool calls with their original `textPosition` values. Leading chars removed = all positions shifted.

### Bug 2: Reconnect mid-stream
Mac agent sends `textPosition` based on total `accumulatedOutput.count` since response start. After iOS reconnects mid-stream, `fullText` only contains text from reconnect point. Server positions exceed local text length → tools placed incorrectly.

## Fixes

### Fix 1 (ConversationView.swift)
Calculate leading trim offset and adjust all tool positions before saving the message.

### Fix 2 (ConnectionManager+API.swift)
Clamp incoming `textPosition` to `min(serverPosition, localFullText.count)` so tools never reference text we don't have.

## Verification
- Stream a message, verify tool positions correct after save (no refresh needed)
- Close app mid-stream, reopen, verify tool positions correct during and after save
- Refresh conversation — should still be correct (unchanged path)
