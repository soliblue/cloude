---
name: speak
description: Generate audio files using Kokoro TTS. Text-to-speech for voiceovers, narration, audio content. Self-contained Python with auto-setup.
user-invocable: true
icon: waveform
aliases: [tts, voice, narrate, audio]
parameters:
  - name: text
    placeholder: What should I say?
    required: true
---

# TTS Audio Generation Skill

Generate WAV audio files from text using Kokoro TTS (82M parameter model). Runs locally via ONNX — no API keys, no cloud.

## When to Use This Skill

- User wants an audio file of spoken text
- Voiceover for a video (pairs with `/video` skill)
- Narration for a recap or presentation
- Any time speech should be saved as a file, not just played back

Do NOT use when:
- User wants real-time playback (use `cloude speak` instead)
- User needs music or sound effects (this is speech only)

## Commands

```bash
# Basic (default voice: af_heart)
python3 /Users/soli/Desktop/CODING/cloude/.claude/skills/speak/generate.py "Hello world"

# Choose a voice
python3 /Users/soli/Desktop/CODING/cloude/.claude/skills/speak/generate.py "Welcome to the show" -v am_adam

# Custom output name
python3 /Users/soli/Desktop/CODING/cloude/.claude/skills/speak/generate.py "Chapter one" -o intro

# Adjust speed (0.5 = slow, 2.0 = fast)
python3 /Users/soli/Desktop/CODING/cloude/.claude/skills/speak/generate.py "Breaking news" -s 1.2

# All options together
python3 /Users/soli/Desktop/CODING/cloude/.claude/skills/speak/generate.py "The quick brown fox" -v bm_george -s 0.9 -o fox-narration

# List voices
python3 /Users/soli/Desktop/CODING/cloude/.claude/skills/speak/generate.py "" --list-voices
```

## Options

- First positional arg: text to synthesize (required)
- `-v`, `--voice`: voice name (default: `af_heart`)
- `-s`, `--speed`: playback speed, 0.5–2.0 (default: 1.0)
- `-o`, `--output`: filename without extension (default: `tts_TIMESTAMP`)

## Voices

| Voice | Description |
|-------|-------------|
| `af_heart` | US Female (Heart) — default |
| `af_bella` | US Female (Bella) |
| `af_nicole` | US Female (Nicole) |
| `af_sarah` | US Female (Sarah) |
| `af_sky` | US Female (Sky) |
| `am_adam` | US Male (Adam) |
| `am_michael` | US Male (Michael) |
| `bf_emma` | UK Female (Emma) |
| `bf_isabella` | UK Female (Isabella) |
| `bm_george` | UK Male (George) |
| `bm_lewis` | UK Male (Lewis) |

Voice naming: `a` = US accent, `b` = UK accent, `f` = female, `m` = male.

## First Run

First run auto-installs everything (takes ~1 min):
1. Creates Python venv in `.claude/skills/speak/venv/`
2. Installs `kokoro-onnx` + `soundfile`
3. Downloads ONNX model + voices (~300MB total) to `.claude/skills/speak/models/`

Subsequent runs: ~5-10s model load + synthesis.

## Output

Default output: `/Users/soli/Desktop/CODING/cloude/.claude/skills/speak/output/`

Files are named `{output}.wav` (24kHz, 16-bit mono).

## After Generating

1. Present the full output path to the user (renders as clickable file pill in iOS)
2. For video narration, combine with ffmpeg: `ffmpeg -i video.mp4 -i narration.wav -c:v copy -c:a aac output.mp4`
