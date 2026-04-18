---
title: "Android Voice Input & Transcription"
description: "Record audio, send to agent for Whisper transcription, insert into chat."
created_at: 2026-04-02
tags: ["android", "audio"]
build: 120
icon: mic
---
# Android Voice Input & Transcription {mic}
<!-- status: blocked -->


## Status

Android implementation is complete. Blocked on Mac agent WhisperService failing to initialize due to HuggingFace network timeout on model validation.

### What's done
- `AudioRecorder.kt` - records 16kHz 16-bit mono PCM, wraps in WAV, returns base64
- `InputBar.kt` - mic button (replaces send when text empty + whisperReady), recording indicator with pulsing dot + audio level bars, transcribing spinner
- `ChatViewModel.kt` - transcribe(), isTranscribing, pendingTranscription flows, handles ServerMessage.Transcription
- `EnvironmentConnection.kt` - tracks whisperReady StateFlow from ServerMessage.WhisperReady
- `AndroidManifest.xml` - RECORD_AUDIO permission added
- Permission requested at runtime via activity result launcher

### What's blocking
The Mac agent's `WhisperService.initialize()` calls `WhisperKit.download()` which tries to validate/re-download model metadata from HuggingFace on every init, even when the model (1.4GB, medium variant) is already cached at `~/Library/Application Support/Cloude/WhisperModels/`. If the network request times out (NSURLErrorDomain -1001), `isReady` stays false and `whisper_ready: false` is sent to clients, so the mic button never appears.

**Agent log evidence (2026-03-27):**
```
[ERROR] [WhisperService.initialize()] Failed to initialize: Error Domain=NSURLErrorDomain Code=-1001 "The request timed out."
```

### Fix needed
Option A: Restart Mac agent with good network so WhisperKit can validate the cached model.
Option B: Modify `WhisperService.swift` to catch the download timeout and fall back to loading the locally cached model directly via `WhisperKit(modelFolder:)`.

**Files (iOS reference):** AudioRecorder.swift, GlobalInputBar+Recording.swift, GlobalInputBar+AudioWaveform.swift
**Files (Android):** AudioRecorder.kt, InputBar.kt, ChatViewModel.kt, EnvironmentConnection.kt
