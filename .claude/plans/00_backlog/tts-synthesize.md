# TTS Synthesize

> Text-to-speech synthesis support - currently no-op on both Mac and Linux relays

## What
Implement the `synthesize` message handler to generate audio from text and send it back as base64 audio data. Currently both relays ignore this message type.

## Considerations
- Mac agent could use macOS AVSpeechSynthesizer or Kokoro
- Linux relay could use a Python TTS library
- Need to decide on audio format (mp3/wav/m4a)
