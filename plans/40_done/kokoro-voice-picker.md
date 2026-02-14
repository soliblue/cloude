# Kokoro Voice Picker

**Status**: Testing
**Created**: 2026-02-09

## What
Configurable Kokoro TTS voice in Settings. When TTS mode is set to Natural, a voice picker appears with all available Kokoro voices (11 voices across US/UK, male/female).

## Changes
- `Theme.swift` — Added `KokoroVoice` enum with all 11 Kokoro voices (label, accent, gender)
- `ClientMessage.swift` — Added optional `voice` param to `synthesize` message
- `TTSService.swift` — Thread voice through `speak()` → `onSynthesizeRequest` callback
- `ConnectionManager+API.swift` — Pass voice to synthesize WebSocket message
- `MainChatView.swift` — Wire voice through synthesize request callback
- `ChatView+MessageBubble.swift` — Read `kokoroVoice` from AppStorage, pass to speak calls
- `KokoroService.swift` — Accept voice parameter in `synthesize()`, select from loaded voices
- `AppDelegate+MessageHandling.swift` — Pass voice from message to handler
- `Cloude_AgentApp.swift` — Thread voice to KokoroService
- `SettingsView.swift` — Voice picker row (only shown when Natural mode selected)

## Voices
| ID | Label | Accent | Gender |
|----|-------|--------|--------|
| af_heart | Heart | US | Female |
| af_bella | Bella | US | Female |
| af_nicole | Nicole | US | Female |
| af_sarah | Sarah | US | Female |
| af_sky | Sky | US | Female |
| am_adam | Adam | US | Male |
| am_michael | Michael | US | Male |
| bf_emma | Emma | UK | Female |
| bf_isabella | Isabella | UK | Female |
| bm_george | George | UK | Male |
| bm_lewis | Lewis | UK | Male |

## Test
1. Settings → TTS → Natural → voice picker should appear
2. Pick a different voice → play a message → should use that voice
3. Switch to Standard → voice picker should disappear
4. Default should be Heart (af_heart)
