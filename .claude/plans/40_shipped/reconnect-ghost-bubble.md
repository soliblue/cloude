---
title: "Fix Ghost Bubble on Foreground Resume"
description: "Keep reconnecting streams attached to their existing live bubble so foreground resume does not create an empty duplicate bubble."
created_at: 2026-04-03
tags: ["streaming", "connection"]
icon: arrow.clockwise
build: 133
---


# Fix Ghost Bubble on Foreground Resume

Tags: bugfix, streaming

## Bug

When the app is backgrounded during active streaming and reopened, a new empty loading bubble appears below the message that was being streamed, even though the server is continuing the same response. The user sees a duplicate: the interrupted message (with content) plus a ghost empty bubble below it.

## Root Cause

`handleForegroundTransition()` calls `handleDisconnect()` which unconditionally sets `output.isRunning = false` and `output.reset()` before reconnection can determine whether the server is still streaming.

Later, when `handleHistorySync` fires after reconnecting:
- It replaces messages (showing the interrupted one with content)
- It checks `output.isRunning` to decide whether to `seedForReconnect`
- But `isRunning` is already `false`, so seeding is skipped
- When new streaming chunks arrive, a fresh empty live message is inserted instead of continuing the existing one

## Sequence (current broken flow)

1. Background: `handleDisconnect()` -> `output.flushBuffer()`, save message with `wasInterrupted = true`, set `interruptedSession`, `output.reset()`, `output.isRunning = false`
2. Foreground: `reconnect()` -> new WebSocket -> authenticate
3. Auth success: `requestMissedResponse` sent (because `interruptedSession` exists)
4. Server reports conversation still running -> `.reconnectRunning` -> `syncHistory`
5. `handleHistorySync`: replaces messages, checks `output.isRunning` (false) -> skips `seedForReconnect`
6. Server sends new streaming chunk -> needs a live message -> `insertLiveMessage` creates empty bubble
7. User sees: interrupted message with content + new empty bubble below it

## Key Files

- `/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Shared/Services/ConnectionManager.swift` (handleForegroundTransition)
- `/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Shared/Services/EnvironmentConnection+MessageHandler.swift` (handleDisconnect)
- `/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Features/Conversation/Utils/ConversationEventHandling.swift` (handleHistorySync, handleDisconnect)
- `/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Features/Conversation/Store/ConversationStore+Messages.swift` (insertLiveMessage, resumeOrInsertLiveMessage)
- `/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Shared/Services/EnvironmentConnection+Handlers.swift` (missedResponse handler, checkForMissedResponse)
- `/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Shared/Services/EnvironmentConnection+Networking.swift` (reconnect, checkForMissedResponse)

## Hypothesis

The fix should make `handleHistorySync` aware that the conversation was interrupted (not just check `isRunning`). Options:

A. Don't kill `isRunning` in `handleDisconnect` when `interruptedSession` is set, only kill it when the missed response resolves.
B. In `handleHistorySync`, check `wasInterrupted` on the last message instead of `output.isRunning` to decide whether to seed.
C. Track a separate flag like `wasInterruptedByBackground` that survives the reset cycle.

## Codex Consultation

Pending.

## Status

In progress.
