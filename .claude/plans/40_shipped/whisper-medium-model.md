---
title: "Whisper Medium Model Upgrade"
description: "Upgraded WhisperKit from base to medium model for better transcription accuracy with multilingual audio."
created_at: 2026-03-14
tags: ["input", "agent"]
icon: waveform
build: 86
---


# Whisper Medium Model Upgrade {waveform}
## Changes
- `WhisperService.swift`: Changed `modelVariant` from `"base"` to `"medium"`

## Testing
- [ ] Rebuild Mac agent
- [ ] Verify medium model downloads on first launch
- [ ] Test transcription accuracy with English audio
- [ ] Test with mixed language audio (Arabic/German/English)
