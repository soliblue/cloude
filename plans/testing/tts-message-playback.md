# TTS Message Playback {speaker.wave.3}
<!-- build: 67 -->
<!-- priority: 4 -->
<!-- tags: messages, settings -->

> Long press assistant message → "Play". Three-tier TTS setting in Settings: Off / Standard / Natural.

## TTS Engines

| Setting | Engine | Quality | Download |
|---------|--------|---------|----------|
| Off | — | — | — |
| Standard | AVSpeechSynthesizer | Robotic, instant | 0 (built-in) |
| Natural | Kokoro via kokoro-ios SPM | Near-human | ~86MB first-time download |

## Implementation

### Settings
- New "Text to Speech" section in SettingsView
- Three-option picker: Off / Standard / Natural
- Persist choice in UserDefaults
- When Natural selected: show download status/progress if model not yet downloaded

### TTSService
- New `TTSService.swift` — single interface, two backends
- `TTSEngine` enum: `.off`, `.standard`, `.natural`
- Standard: `AVSpeechSynthesizer`, strip markdown, speak
- Natural: kokoro-ios SPM package, download model on first use, cache locally
- Model source: `hexgrad/Kokoro-82M` quantized (~86MB) from HuggingFace
- Show playing indicator on the message bubble while speaking
- Stop playback if user taps again or navigates away

### Context Menu
- Long press assistant message → "Play" option (only if TTS not Off)
- If already playing that message → "Stop"

### kokoro-ios Integration
- Add `https://github.com/mlalma/kokoro-ios` as SPM dependency
- Model files stored in app's Documents directory
- Download with progress indicator on first use
- Reference: KokoroTestApp for integration pattern

## Files
- `TTSService.swift` (new) — engine abstraction + both backends
- `ChatView+MessageBubble.swift` — context menu Play/Stop
- `SettingsView+Components.swift` — TTS setting picker
- `ConnectionManager.swift` or `UserDefaults` — persist setting
