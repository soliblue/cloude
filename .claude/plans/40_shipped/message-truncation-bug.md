---
title: "Message Truncation Bug"
description: "Fixed intermittent message truncation where assistant responses were cut off."
created_at: 2026-03-01
tags: ["streaming"]
icon: exclamationmark.bubble
build: 81
---


# Message Truncation Bug
## Problem
Assistant messages get cut off — user doesn't see the full response. Happens intermittently. User reported multiple instances in a single conversation where the end of messages was missing.

## Investigation Areas
- Streaming parser dropping final chunks
- WebSocket message fragmentation / size limits
- StreamingMarkdownView truncating long content
- MessageBubble layout clipping text
- Connection dropping before stream completes

## Priority
High — users can't read full responses, breaks core chat UX.
