# Whisper Medium Model Upgrade {waveform}
<!-- priority: 10 -->
<!-- tags: input, agent -->

> Upgraded WhisperKit from base to medium model for better transcription accuracy with multilingual audio.

## Changes
- `WhisperService.swift`: Changed `modelVariant` from `"base"` to `"medium"`

## Testing
- [ ] Rebuild Mac agent
- [ ] Verify medium model downloads on first launch
- [ ] Test transcription accuracy with English audio
- [ ] Test with mixed language audio (Arabic/German/English)
