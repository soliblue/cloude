# Linux relay: local speech-to-text with faster-whisper

## Summary
Added local transcription support to the Linux relay using faster-whisper (base model, int8, CPU).

## Changes
- `linux-relay/transcribe.py` - Python script that receives base64 WAV audio via stdin, transcribes with faster-whisper, returns JSON
- `linux-relay/handlers.js` - Wired up `transcribe` message type to spawn the Python script
- `linux-relay/server.js` - Changed `whisper_ready` from `false` to `true` on auth
- `linux-relay/whisper-env/` - Python venv with faster-whisper installed
- `linux-relay/whisper-models/` - Cached whisper base model (~150MB)

## Details
- Model: `base` (good accuracy, ~500MB RAM, fits CX22's 4GB)
- Compute: `int8` on CPU via CTranslate2
- Filters out blank audio / silence artifacts
- Matches the same protocol the iOS app already uses (transcribe → transcription)
