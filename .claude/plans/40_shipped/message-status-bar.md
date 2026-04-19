---
title: "Message Status Bar"
description: "Restore the compact status line shown after each assistant message with duration, model, and cost."
created_at: 2026-03-29
tags: ["ui"]
icon: info.circle
build: 120
---


# Message Status Bar
## Problem
The status bar that used to appear below each assistant message is missing. It showed key stats at a glance without needing to open the info sheet.

## Desired Outcome
A compact single-line status bar appears after each completed assistant message showing exactly three values: duration, model name, and cost. It should be subtle and not compete visually with the message content.

## How to Test
1. Send a message and wait for the response to complete
2. Below the assistant message, a status line should appear
3. It should show the response duration (e.g. "12s"), model name (e.g. "claude-sonnet-4-6"), and cost (e.g. "$0.023")
4. It should not appear on user messages
5. It should not appear while the response is still streaming
