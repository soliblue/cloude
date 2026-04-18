---
title: "Streaming Perf Round 2"
description: "Reduce parent and container re-renders around the streaming path without changing the streaming logic."
created_at: 2026-04-03
tags: ["performance"]
icon: gauge.with.dots.needle.bottom.50percent
build: 133
---


# Streaming Perf Round 2

## Goal
Reduce parent/container churn without touching streaming logic.

## Reproduction
- `.claude/skills/sim/scripts/run-perf-scenario.sh --scenario mixed-markdown-multi-tool.txt --wait 45`

## Instrumentation
- Baseline render logging already enabled via `debugOverlayEnabled`
- Sources: `LiveBubble`, `ConvView`, `MainChat`, `WindowTabBar`, `InputBar`

## Baseline Numbers
- Starting point: local commit `3d56bec7`
- `LiveBubble: 247`
- `ConvView: 32`
- `MainChat: 16`
- `WindowTabBar: 2`
- `InputBar: 19`

## Root-Cause Hypothesis
`ConversationView` still received `isKeyboardVisible` through the workspace stack even though it never used it. That widened invalidation scope and made the chat container rerender around input state changes for no reason.

## Fix
Remove the unused `isKeyboardVisible` parameter from `ConversationView` and stop passing it from `WorkspaceView+Windows`.

## Consultation Summary
Kept the change minimal and isolated to an obviously unused prop to avoid another broad row-wrapper regression.

## After Numbers
Run 1:
- `LiveBubble: 319`
- `ConvView: 24`
- `MainChat: 12`
- `WindowTabBar: 2`
- `InputBar: 15`

Run 2:
- `LiveBubble: 242`
- `ConvView: 24`
- `MainChat: 12`
- `WindowTabBar: 2`
- `InputBar: 15`

## Regression Results
- No behavior change expected because the prop was unused.
- Same canonical mixed markdown multi-tool scenario still completed normally.
- FPS stayed around `60-61` in the steady state.

## Approval
Accepted.

## Shared Artifact Updated
- Added this round note so later rounds can treat `ConversationView` keyboard invalidation as already addressed.
