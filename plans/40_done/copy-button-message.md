# Copy Button on Assistant Messages
<!-- build: 67 -->

**Status**: Testing
**Created**: 2026-02-08

## What
Add an inline copy button to the left of the refresh button on every assistant message bubble footer.

## Changes
- `ChatView+MessageBubble.swift`: Added `doc.on.doc` copy button before the refresh button in the assistant message HStack. Reuses existing `showCopiedToast` state and toast overlay.
