# Fork Button in Window Header

**Stage**: Testing
**Build**: 56

## What
Add the fork/duplicate conversation button to the window header (top bar), before the refresh button.

## Changes
- `MainChatView.swift`: Added fork button (`arrow.triangle.branch`) between Spacer and refresh button in `windowHeader()`, visible when conversation has a session ID

## Test
- Open a conversation with a session ID → fork button should appear in the header
- Tap it → should create a new forked conversation and link the window to it
- New conversation without session ID → no fork button
