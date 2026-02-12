---
name: speak
description: Generate audio files using Kokoro (local) or ElevenLabs (cloud, cinematic quality). Text-to-speech for voiceovers, narration, audio content.
user-invocable: true
icon: waveform
aliases: [tts, voice, narrate, audio]
parameters:
  - name: text
    placeholder: What should I say?
    required: true
---

# TTS Audio Generation Skill

Two engines:
- **Kokoro** (default) — local, free, fast, decent quality. Good for drafts and quick TTS.
- **ElevenLabs** — cloud, cinematic quality, emotional, expressive. Use for final narration and polished audio. Requires API key in `.claude/skills/speak/.env`.

**Use ElevenLabs for narration and cinematic audio. Use Kokoro for quick drafts.**

## When to Use This Skill

- User wants an audio file of spoken text
- Voiceover for a video (pairs with `/video` skill)
- Narration for a recap or presentation
- Any time speech should be saved as a file, not just played back

Do NOT use when:
- User wants real-time playback (use `cloude speak` instead)
- User needs music or sound effects (this is speech only)

## Commands

### Kokoro (local, free)

```bash
# Basic (default voice: af_heart)
python3 .claude/skills/speak/generate.py "Hello world"

# Choose a voice
python3 .claude/skills/speak/generate.py "Welcome to the show" -v am_adam

# Adjust speed (0.5 = slow, 2.0 = fast)
python3 .claude/skills/speak/generate.py "Breaking news" -s 1.2

# List kokoro voices
python3 .claude/skills/speak/generate.py --list-voices
```

### ElevenLabs (cloud, cinematic)

```bash
# Basic with ElevenLabs (uses Adam voice by default)
python3 .claude/skills/speak/generate.py "Hello world" -e elevenlabs

# Choose a voice by ID (get IDs from --list-voices)
python3 .claude/skills/speak/generate.py "Deep narration" -e eleven -v pNInz6obpgDQGcFmaJgB

# More expressive (lower stability = more emotion)
python3 .claude/skills/speak/generate.py "This is dramatic" -e eleven --stability 0.3 --style 0.4

# Cinematic narration recipe (recommended for videos)
python3 .claude/skills/speak/generate.py "The story begins..." -e eleven --stability 0.35 --similarity 0.8 --style 0.3 -o cinematic-narration

# List ElevenLabs voices
python3 .claude/skills/speak/generate.py -e eleven --list-voices

# Use turbo model (faster, slightly lower quality)
python3 .claude/skills/speak/generate.py "Quick test" -e eleven -m turbo_v2_5
```

## Options

### Shared
- First positional arg: text to synthesize (required)
- `-e`, `--engine`: `kokoro` (default) or `elevenlabs`/`eleven`
- `-v`, `--voice`: voice name/ID
- `-o`, `--output`: filename without extension
- `--list-voices`: show available voices

### Kokoro only
- `-s`, `--speed`: playback speed, 0.5–2.0 (default: 1.0)

### ElevenLabs only
- `-m`, `--model`: `multilingual_v2` (default, best), `turbo_v2_5` (faster), `flash_v2_5` (fastest)
- `--stability`: 0-1, lower = more expressive/dramatic (default: 0.4)
- `--similarity`: 0-1, voice similarity boost (default: 0.8)
- `--style`: 0-1, style exaggeration (default: 0.15, use 0.3+ for dramatic narration)

## Kokoro Voices

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

## ElevenLabs Voices

Run `--list-voices -e eleven` to see all available voices with IDs. Popular ones:
- **Adam** (`pNInz6obpgDQGcFmaJgB`) — deep male, great for narration
- **Rachel** (`21m00Tcm4TlvDq8ikWAM`) — calm female
- **Clyde** (`2EiwWnXFnvU5JabPnv8n`) — deep male, authoritative
- **Dave** (`CYw3kZ02Hs0563khs1Fj`) — conversational male
- **Fin** (`D38z5RcWu1voky8WS1ja`) — elderly male, wise

Use `--list-voices` to get the full list with descriptions.

## ElevenLabs Setup

Add API key to `.claude/skills/speak/.env` (gitignored):
```
ELEVEN_API_KEY=sk_your_key_here
```

## First Run (Kokoro only)

First run auto-installs everything (takes ~1 min):
1. Creates Python venv in `.claude/skills/speak/venv/`
2. Installs `kokoro-onnx` + `soundfile`
3. Downloads ONNX model + voices (~300MB total) to `.claude/skills/speak/models/`

ElevenLabs needs no setup beyond the API key — uses stdlib only.

## Output

Default output: `.claude/skills/speak/output/`
- Kokoro: `{output}.wav` (24kHz, 16-bit mono)
- ElevenLabs: `{output}.mp3` (high quality)

## After Generating

1. Present the full output path to the user (renders as clickable file pill in iOS)
2. For video narration, combine with ffmpeg: `ffmpeg -i video.mp4 -i narration.mp3 -c:v copy -c:a aac output.mp4`
