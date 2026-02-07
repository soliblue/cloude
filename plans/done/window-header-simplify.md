# Window Header Simplify

## Status: Testing

## Summary
Removed tab icons (chat/files/git) from window header. Moved conversation title + directory to the left. Added refresh button and close button on the right with a divider separator.

## Changes
- `MainChatView.swift` — `windowHeader()`: removed tab icon loop, moved ConversationInfoLabel to left, added refresh (arrow.clockwise) + divider + close (xmark) on right
- Extracted `refreshConversation(for:)` helper for sync history

## Context
The git tab icon was broken — `onGitStatus` is a single closure that gets overwritten by GitChangesView, and `checkGitForAllDirectories()` only runs once on appear (misses directories assigned later). Rather than fix the tab system, simplified the header. Tabs can return later as `cloude` commands.

## Test
- [ ] Header shows conversation name + directory on left
- [ ] Refresh button syncs history
- [ ] Close button removes window
- [ ] Divider visible between refresh and close
