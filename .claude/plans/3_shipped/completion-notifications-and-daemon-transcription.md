---
title: "Completion Notifications and macOS Daemon Transcription"
description: "Restore iOS completion notifications and implement macOS daemon voice transcription via Speech framework."
created_at: 2026-06-10
tags: ["ui", "agent"]
icon: bell
build: 156
---

# Completion Notifications and macOS Daemon Transcription

## iOS Completion Notifications

New ChatNotificationService wraps UNUserNotificationCenter for lazy permission request and local notification posting. When app is backgrounded, stream completion posts a system notification with session title and response snippet; when active but unfocused, falls back to existing toast behavior.

- ChatNotificationService.swift: permission + notification API
- ChatService.swift: permission requested on first send; maybePresentToast renamed to notifyCompletion with backgrounded-app branching logic

## macOS Daemon Voice Transcription

TranscribeHandler implements POST /sessions/:id/transcribe via Apple's Speech framework (SFSpeechRecognizer), with on-device when supported. Matches Linux daemon contract:

- 200: {"text": transcribed_text}
- 400: missing_audio
- 503: transcription_unavailable
- 500: transcription_failed

Infoplist usage description added to both build configs.
