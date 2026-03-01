# Message Truncation Bug
<!-- build: 82 -->

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
