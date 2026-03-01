# Move Audio Enums Out of Theme.swift

**Status**: Testing
**Type**: Refactor

## What
Moved `TTSMode` and `KokoroVoice` enums from `Utilities/Theme.swift` to new `Utilities/AudioConfig.swift`. These audio/TTS configuration enums had nothing to do with theming.

## Files Changed
- `Utilities/Theme.swift` — removed TTSMode + KokoroVoice
- `Utilities/AudioConfig.swift` — new file with the two enums
