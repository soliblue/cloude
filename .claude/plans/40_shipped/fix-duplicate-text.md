---
title: "Fix Duplicate Text in Streaming Output"
description: "Stop the Mac agent from re-emitting assistant text after streaming deltas so responses do not duplicate in chat."
created_at: 2026-03-28
tags: ["streaming", "agent"]
icon: doc.on.doc
build: 120
---


# Fix Duplicate Text in Streaming Output
Removed text re-emission from `handleAssistantMessage` in the Mac agent. Text was being sent twice: once via `content_block_delta` streaming events and again when the full `assistant` message arrived. The `.contains()` dedup check was fragile due to extra `\n\n` separators.

## Test
- Send a message and verify no duplicated text in the response
- Check multi-turn conversations for any missing text
- Verify tool calls still display correctly
