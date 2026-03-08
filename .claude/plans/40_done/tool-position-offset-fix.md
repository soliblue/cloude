# Fix: Tool call positions offset after message save / reconnect
<!-- priority: 10 -->
<!-- tags: tools, ui -->
<!-- build: 56 -->

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
