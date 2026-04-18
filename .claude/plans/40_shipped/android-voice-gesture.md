---
title: "Android Voice Input Gesture"
description: "Improve voice input with hold-to-record gesture and swipe-to-cancel."
created_at: 2026-04-03
tags: ["android", "input", "voice"]
build: 125
icon: mic.fill
---
# Android Voice Input Gesture {mic.fill}


## Desired Outcome
Replace tap-to-toggle recording with a more intuitive gesture: long-press the mic button to start recording, release to send for transcription. Swipe left while holding to cancel without sending.

## How iOS Does It
- Swipe up (>=60pt) on mic button starts recording
- Swipe left while recording cancels
- Release sends audio for transcription

## Android Implementation
- Long-press on mic button starts recording
- Visual feedback: button scales up, waveform appears
- Release finger sends audio for transcription
- Drag left (>=60dp) while holding cancels recording with haptic feedback
- Optional: keep single-tap as fallback for accessibility

## Files
- InputBar.kt - gesture detection, visual feedback
- AudioRecorder.kt - recording start/stop (already exists)
