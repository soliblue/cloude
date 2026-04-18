---
title: "Fix Streaming Re-renders"
description: "Eliminate unnecessary re-renders of non-live message bubbles during streaming."
created_at: 2026-03-31
tags: ["streaming", "performance"]
icon: gauge.with.dots.needle.bottom.50percent
build: 122
---


# Fix Streaming Re-renders {gauge.with.dots.needle.bottom.50percent}
## Problem
During streaming, ALL message bubbles observed `ConversationOutput` via `@ObservedObject`, causing every bubble to re-render ~60x/sec when only the live message needs updates.

## Fix
In `MessageBubble+LiveWrapper.swift`, replaced `@ObservedObject var output` with `let output` + `@State` + `.onReceive`. Non-live messages' `onReceive` closures fire but don't update `@State`, so SwiftUI skips their body evaluation entirely.

## Results
| Metric | Before | After |
|--------|--------|-------|
| Total renders per stream | 9,233 | 1,036 |
| Wasted (live=false) renders | ~8,900 | 16 |
| FPS during streaming | 54-61 | 56-61 |

## Verify
Outcome: during streaming, only the live message bubble re-renders per drain tick.

Test: enable debug overlay, send a streaming message in a 5+ message conversation, confirm LiveBubble renders are almost all `live=true`.
