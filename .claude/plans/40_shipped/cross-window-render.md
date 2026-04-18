---
title: "Cross-Window Render Pollution"
description: "Stop hidden conversation updates from re-rendering the visible window tree and wasting idle work."
created_at: 2026-04-03
tags: ["performance", "windows"]
icon: arrow.left.and.right
build: 133
---


# Cross-Window Render Pollution

Tags: performance

## Goal
- Metric: idle renders on the visible window when a hidden window's conversation is active
- Baseline: ~30 paired (MainChat + ConvView + InputBar) renders over 10 minutes while nothing changes on the visible window
- Target: 0 idle renders when only the hidden conversation is active

## Root Cause

`ConversationOutput` state transitions (text empty/non-empty, isRunning, isCompacting, newSessionId, skipped) call `parent?.objectWillChange.send()` on ConnectionManager. Since WorkspaceView observes ConnectionManager via `@ObservedObject`, ANY conversation's state transition re-renders the entire visible view tree.

The propagation chain:
1. Hidden conversation gets assistant output
2. `ConversationOutput.text` transitions empty -> non-empty
3. `parent?.objectWillChange.send()` fires on ConnectionManager
4. WorkspaceView (which observes ConnectionManager) re-evaluates body
5. MainChat, ConvView, InputBar all re-render even though the visible conversation's state hasn't changed

Also: `EnvironmentConnection.isTranscribing` and `.processes` didSet both call `manager?.objectWillChange.send()`.

## Key Files

- `ConnectionManager+ConversationOutput.swift` - ConversationOutput publishes up to parent
- `ConnectionManager.swift` - @Published connections, manual objectWillChange.send() calls
- `EnvironmentConnection.swift` - isTranscribing/processes propagate up
- `EnvironmentConnection+Networking.swift` - connect/disconnect publish
- `EnvironmentConnection+Handlers.swift` - auth publishes
- `EnvironmentConnection+MessageHandler.swift` - disconnect publishes
- `WorkspaceView.swift` - @ObservedObject var connection

## Hypothesis

ConversationOutput should NOT propagate text/isRunning/isCompacting/newSessionId/skipped changes to ConnectionManager's objectWillChange. These are per-conversation state that only ObservedMessageBubble (via onReceive) needs to see. The parent propagation was needed before the ObservedMessageBubble pattern existed, but now it's redundant for most transitions.

The only transitions that legitimately need to propagate up are:
- isRunning changes (InputBar needs to know if any conversation is running)
- Connection-level state (isConnected, isAuthenticated)

## Proposed Fix

Guard the propagation in ConversationOutput so only `isRunning` changes propagate up. Text transitions, isCompacting, newSessionId, and skipped should stay local to their conversation's observers.

For EnvironmentConnection: `processes` changes should propagate (affects UI), but check if `isTranscribing` needs to.

## Risks

- InputBar might depend on text empty/non-empty transition to show/hide elements
- WorkspaceView might read ConversationOutput state that would become stale

## Codex Consultation

Pending.

## Status

In progress.
