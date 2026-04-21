# Audio (voice-to-text) feature

## Goal

Hold-to-speak voice input that transcribes to text and injects it into the chat input bar.

## Product behavior

- Swipe up on the input bar's trailing area → recording starts.
- Overlay covers the input bar: pulsing indicator + live 7-bar waveform (driven by mic level) + a stop button.
- Release / tap stop → the waveform freezes, a spinner replaces it, the audio blob POSTs to the daemon, and the transcribed text lands in the input bar. User reviews, optionally edits, then sends.
- Permissions prompt via `NSMicrophoneUsageDescription` (already set in v2 `Info.plist`: "Cloude uses the microphone for voice-to-text input").
- Idle timer disabled while recording.
- **No min recording length** (matches cloude-main). The daemon's blank filter handles short noise bursts.
- **Haptics**: `.impact(.light)` on record start, `.impact(.medium)` on stop. Follows iOS best practice (confirm-style action).
- **Pending-audio persistence**: the recorded WAV is written to `Documents/pending_audio.wav` during recording. On transcription failure, the file stays on disk and `hasPendingAudio` flips true so the UI can offer a retry. On success, the file is deleted.

## Blank filter (mirrored from cloude-main)

`WorkspaceStore+EventHandling.swift:12-25`. Lowercased, trimmed, substring match unless noted:

- empty after trim
- contains `"blank_audio"`
- contains `"blank audio"`
- contains `"silence"`
- contains `"no speech"`
- contains `"inaudible"`
- exact equal `"you"`
- exact equal `"thanks for watching"`

On match: discard, do nothing. On non-match: append to input text (space-separated if input non-empty). Either way, clear the pending audio file.

## Transcription backend

**WhisperKit on the macOS daemon**, per user decision. Port `WhisperService.swift` from cloude-main as-is:

- `medium` model variant (~1.5GB).
- Model downloaded on first use into `Application Support/Cloude/WhisperModels/`, progress published so the menubar can show it.
- WAV → `[Float]` samples (drop the 44-byte header, int16 → float divide by Int16.max).
- Strip `\[.*?\]` regex artifacts from the result.
- Free, offline, no API key, no per-minute cost.

## Architecture (v2 layout)

```
clients/ios/src/Features/Audio/
  UI/
    AudioInputOverlay.swift      // covers input bar during recording + transcribing; waveform fed by AudioRecorder.audioLevel; spinner during AudioService.transcribe
  Logic/
    AudioRecorder.swift          // AVAudioRecorder (16kHz mono PCM WAV), 50ms metering poll, Documents/pending_audio.wav persistence; the only stateful device wrapper we allow in Logic/
    AudioService.swift           // stateless; POST /audio (raw WAV body) -> String; applies blank filter client-side
```

Chat input bar integration lives in `Features/Chat/UI/ChatInputBar.swift`:
- DragGesture (≥60pt upward) on the send button area → present `AudioInputOverlay`.
- On transcription result (non-blank), append to bound input text.
- Haptic `.light` on gesture begin (start), `.medium` on release (stop).

Daemon side:
```
daemons/macos/src/Handlers/AudioHandler.swift
  POST /audio    transcribe()   // raw WAV body (Content-Type: audio/wav), returns {"text": "..."}
daemons/macos/src/Services/TranscriptionService.swift
  // WhisperKit wrapper - port from cloude-main's WhisperService.swift
```

## Port map (cloude-main → v2)

| cloude-main | v2 target | Notes |
|---|---|---|
| `Features/Workspace/Services/Workspace+AudioRecorder.swift` | `Features/Audio/Logic/AudioRecorder.swift` | port as-is: `pending_audio.wav`, `hasPendingAudio`, `clearPendingAudioFile`, 50ms metering, 16kHz mono PCM |
| `Features/Workspace/Views/WorkspaceView+InputBar+AudioWaveform.swift` (`AudioWaveformView`, `RecordingOverlayView`) | `Features/Audio/UI/AudioInputOverlay.swift` | merge into one file; overlay owns the 7-bar waveform |
| `Features/Workspace/Views/WorkspaceView+InputBar+Recording.swift` (swipe gesture) | inline into `Features/Chat/UI/ChatInputBar.swift` | add haptics |
| `Cloude Agent/Services/WhisperService.swift` | `daemons/macos/src/Services/TranscriptionService.swift` | port verbatim, medium variant, WhisperKit SPM dep |
| `WorkspaceStore+EventHandling.swift:12-25` blank-filter | inline filter in `AudioService.transcribe` | returns nil / "" on blank so caller knows to do nothing |

## Step plan

1. Daemon: add WhisperKit SPM dep; port `WhisperService` → `TranscriptionService`; add `AudioHandler.swift` with `POST /audio`; register route in `Router.swift`. Warm up on daemon launch (async, non-blocking; menubar reflects download state).
2. iOS `AudioRecorder.swift` — port cloude-main verbatim (pending_audio.wav persistence, metering, permission request).
3. iOS `AudioService.swift` — POST raw WAV to `/audio`, apply blank filter, return `String?` (nil on blank or failure).
4. iOS `AudioInputOverlay.swift` — 7-bar waveform driven by `recorder.audioLevel`, pulsing dot, stop button; two states (`.recording` / `.transcribing`).
5. Wire into `ChatInputBar.swift` — DragGesture upward ≥60pt → present overlay; on stop → transcribe → append → dismiss. Haptics at start/stop.
6. Test: swipe, say a sentence, verify text lands in input. Perf intervals `audio.record.ms`, `audio.transcribe.ms`.

## Instrumentation for tester

- `begin/endInterval("audio.record", key: sessionId)` around start → stop.
- `begin/endInterval("audio.transcribe", key: sessionId)` around POST /audio.
- Daemon logs WhisperKit model load progress + transcription duration.

No new deep link for audio (tester exercises it via UI; audio path is not on the `/loop` tester surface for v1).

## Out of scope

- Language selection (auto-detect only, v1).
- Streaming partial transcription.
- Voice-activity detection / auto-stop.
- Retry UI for pending audio (file is persisted; surfacing it in UI is a v2 polish pass).
