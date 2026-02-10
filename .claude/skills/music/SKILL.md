---
name: music
description: Generate background music using MusicGen. Text-to-music for recaps, videos, ambient tracks. Self-contained Python with auto-setup.
user-invocable: true
icon: music.note
aliases: [song, beat, soundtrack, bgm]
parameters:
  - name: prompt
    placeholder: Describe the music
    required: true
---

# Music Generation Skill

Generate WAV audio from text descriptions using Meta's MusicGen small (300M params). Runs locally — no API keys, no cloud.

## When to Use This Skill

- Background music for `/recap` daily shorts
- Soundtrack for `/video` content
- Ambient tracks, beats, mood music
- Any time you need original music generated locally

Do NOT use when:
- User wants speech/narration (use `/speak`)
- User wants a specific copyrighted song

## Commands

```bash
# Custom prompt
python3 /Users/soli/Desktop/CODING/cloude/.claude/skills/music/generate.py "calm ambient electronic music with soft pads"

# Use a mood preset
python3 /Users/soli/Desktop/CODING/cloude/.claude/skills/music/generate.py "" -m recap

# 30 seconds for a recap
python3 /Users/soli/Desktop/CODING/cloude/.claude/skills/music/generate.py "upbeat cinematic electronic" -d 30 -o recap-bgm

# Short 10s loop
python3 /Users/soli/Desktop/CODING/cloude/.claude/skills/music/generate.py "lo-fi chill beat" -d 10 -o chill-loop

# List mood presets
python3 /Users/soli/Desktop/CODING/cloude/.claude/skills/music/generate.py "" --list-moods
```

## Options

- First positional arg: text description of music (required, or empty string with `-m`)
- `-d`, `--duration`: duration in seconds (default: 10)
- `-m`, `--mood`: use a preset mood instead of custom prompt
- `-o`, `--output`: filename without extension (default: `music_TIMESTAMP`)

## Mood Presets

| Mood | Description |
|------|-------------|
| `ambient` | Calm ambient electronic, minimal, dreamy |
| `upbeat` | Energetic electronic, positive, driving |
| `cinematic` | Orchestral, epic, sweeping, emotional |
| `chill` | Lo-fi hip hop beat, relaxed, warm |
| `dark` | Dark atmospheric, moody, suspenseful |
| `happy` | Cheerful acoustic, bright, playful |
| `focus` | Minimal ambient, soft pads, no drums |
| `recap` | Upbeat cinematic electronic, inspiring, building |

## Performance

- **First run**: ~5 min (venv + ~2GB model download)
- **Generation**: ~30s per 10s of audio on Apple Silicon CPU
- **30s recap track**: ~90s generation time
- MPS (GPU) not supported — runs on CPU

## Output

Default output: `/Users/soli/Desktop/CODING/cloude/.claude/skills/music/output/`

Files are named `{output}.wav` (32kHz mono).

## Recap Integration

For daily recaps, generate a unique 30s background track:

```bash
python3 /Users/soli/Desktop/CODING/cloude/.claude/skills/music/generate.py "upbeat inspiring electronic music, building momentum, modern cinematic" -d 30 -o recap-bgm-2026-02-10
```

Then mix with narration using ffmpeg (lower music volume under speech):

```bash
ffmpeg -y -i recap-silent.mp4 -i recap-bgm.wav -i narration.wav \
  -filter_complex "[1:a]volume=0.3[bg];[2:a]adelay=300|300[narr];[bg][narr]amix=inputs=2:duration=shortest[aout]" \
  -map 0:v -map "[aout]" -c:v copy -c:a aac -b:a 128k -shortest recap-final.mp4
```
