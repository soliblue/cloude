---
title: "Stop Button Shows Immediately When Input Empty"
description: "Show stop button immediately during streaming when input is empty instead of a 3-second delay."
created_at: 2026-03-03
tags: ["input", "ui"]
icon: stop.fill
build: 82
---


# Stop Button Shows Immediately When Input Empty {stop.fill}
## Problem
When streaming with empty input (not focused), a disabled send button showed for ~3 seconds before the stop button appeared. Confusing UX.

## Fix
`shouldShowStopButton` now returns true immediately when `isRunning && !isInputFocused && !canSend` — no delay needed when there's nothing to send anyway. The 3-second delay still applies when there's text in the field.

## File
- `GlobalInputBar+ActionButton.swift:8` — added `|| !canSend` to condition
