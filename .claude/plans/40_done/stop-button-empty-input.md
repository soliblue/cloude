# Stop Button Shows Immediately When Input Empty {stop.fill}
<!-- priority: 10 -->
<!-- tags: input, ui -->

> Show stop button immediately during streaming when input is empty instead of a 3-second delay.

## Problem
When streaming with empty input (not focused), a disabled send button showed for ~3 seconds before the stop button appeared. Confusing UX.

## Fix
`shouldShowStopButton` now returns true immediately when `isRunning && !isInputFocused && !canSend` — no delay needed when there's nothing to send anyway. The 3-second delay still applies when there's text in the field.

## File
- `GlobalInputBar+ActionButton.swift:8` — added `|| !canSend` to condition
