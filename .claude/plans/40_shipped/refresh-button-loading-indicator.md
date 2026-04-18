---
title: "Refresh Button Loading Indicator"
description: "Replaced static refresh icon with a spinner while conversation history is syncing."
created_at: 2026-02-13
tags: ["ui", "header"]
icon: progress.indicator
build: 71
---


# Refresh Button Loading Indicator {progress.indicator}
## Problem
When tapping the refresh button in the window header, the button stays as the static refresh icon even while the conversation is syncing. No visual feedback that anything is happening.

## Solution
Replace the refresh icon with a `ProgressView` spinner while the history sync is in progress. Track refreshing state by session ID — set it when refresh is tapped, clear it when `historySync` or `historySyncError` event arrives.

## Files
- `MainChatView.swift` — header refresh button + state tracking
