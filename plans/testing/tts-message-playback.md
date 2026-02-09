# TTS Message Playback {speaker.wave.3}
<!-- build: 67 -->
<!-- priority: 4 -->
<!-- tags: messages, settings, mac-agent -->

> Three-tier TTS: Off / Standard / Natural. Standard uses iOS built-in voice. Natural uses Kokoro AI on Mac agent (like Whisper).

## Architecture

Kokoro runs on Mac agent (MLX crashes on iOS). Same pattern as Whisper:
- iOS sends `synthesize(text, messageId)` → Mac agent
- Mac agent runs Kokoro TTS, returns WAV audio as base64
- iOS receives `ttsAudio(audioBase64, messageId)` and plays it

## TTS Engines

| Setting | Engine | Where | Quality | Download |
|---------|--------|-------|---------|----------|
| Off | — | — | — | — |
| Standard | AVSpeechSynthesizer | iOS | Robotic, instant | 0 (built-in) |
| Natural | Kokoro via kokoro-ios SPM | Mac agent | Near-human | ~86MB first-time |

## Changes

### Shared Protocol (CloudeShared)
- `ClientMessage.synthesize(text, messageId)` — iOS → Mac
- `ServerMessage.ttsAudio(audioBase64, messageId)` — Mac → iOS
- `ServerMessage.kokoroReady(ready)` — status broadcast

### Mac Agent
- `KokoroService.swift` — downloads model on first use, synthesizes text to WAV
- AppDelegate: `initializeKokoro()` + `handleSynthesize()`
- Sends `kokoroReady` on auth like `whisperReady`

### iOS
- `TTSService.swift` — Natural mode sends synthesize request via callback
- `ConnectionManager` — handles `ttsAudio` and `kokoroReady` messages
- `MainChatView` — wires `onTTSAudio` → `TTSService.playAudio`
- `Theme.swift` — "Kokoro AI" (removed "coming soon")

## Files Changed
- `CloudeShared/Messages/ClientMessage.swift`
- `CloudeShared/Messages/ServerMessage.swift`
- `CloudeShared/Messages/ServerMessage+Encoding.swift`
- `Cloude Agent/Services/KokoroService.swift` (new)
- `Cloude Agent/App/Cloude_AgentApp.swift`
- `Cloude Agent/App/AppDelegate+MessageHandling.swift`
- `Cloude Agent/Services/WebSocketServer+HTTP.swift`
- `Cloude/Services/TTSService.swift`
- `Cloude/Services/ConnectionManager.swift`
- `Cloude/Services/ConnectionManager+API.swift`
- `Cloude/UI/MainChatView.swift`
- `Cloude/Utilities/Theme.swift`
- `Cloude.xcodeproj/project.pbxproj` (KokoroSwift SPM dep)
