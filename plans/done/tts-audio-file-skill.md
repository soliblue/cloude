# TTS Audio File Skill + Audio Preview

## Summary
Add a `/speak` skill that generates audio files using Kokoro TTS via a self-contained Python script. Also add audio file preview support to the iOS app (play/pause WAV, MP3, etc.).

## Changes

### Skill (`skills/speak/`)
- `generate.py` — self-bootstrapping Python script (auto-creates venv, downloads ONNX model)
- Uses `kokoro-onnx` for synthesis (independent of Mac agent)
- 11 voices, speed control, WAV output
- `.claude/skills/speak/SKILL.md` — skill definition

### iOS Audio Preview
- `FileContentType.swift` — added `.audio` case (wav, mp3, m4a, aac, ogg, flac)
- `FilePreviewView+Previews.swift` — added `AudioPreview` view (play/pause, progress bar, duration)
- `FilePathPreviewView+Content.swift` — route `.audio` to `AudioPreview`

## Use Cases
- Generate voiceover for recap videos
- Create audio content on demand
- Narration for Sora videos
- Preview any audio file from file pills
