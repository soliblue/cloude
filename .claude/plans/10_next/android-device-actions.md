# Android Device Actions {iphone.radiowaves.left.and.right}
<!-- priority: 13 -->
<!-- tags: android, device, features -->

> Screenshot capture, haptic feedback, and completion notifications triggered by Claude Code.

## Context

iOS lets Claude Code trigger device-level actions: capture the current screen (returned as base64 JPEG so Claude can "see" the app), fire haptic vibration at configurable intensity, and send local push notifications when a run completes while the app is backgrounded.

## Scope

### Screenshot Capture
- Capture the current Activity's root view as a bitmap
- Compress to JPEG (70% quality), base64 encode
- Return as a user message with image attachment so Claude can analyze what's on screen

### Haptic Feedback
- Map intensity levels (light/medium/heavy) to Android VibrationEffect presets
- Trigger via deep link or WebSocket command

### Completion Notifications
- When a Claude Code run finishes and the app is backgrounded, fire a local notification
- Show "Claude finished" title with first 100 chars of the response as body
- Tapping the notification opens the conversation

## Dependencies

- Deep links ticket (for triggering via URI)
- Existing foreground service (for notification channel)
