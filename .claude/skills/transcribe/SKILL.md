---
name: transcribe
description: Transcribe audio files to text using Whisper. Speech-to-text for voice notes, meetings, audio content.
user-invocable: true
disable-model-invocation: true
icon: ear
aliases: [stt]
parameters:
  - name: file
    placeholder: Path to audio file
    required: true
---

# Speech-to-Text Transcription Skill

Transcribe audio files to text using OpenAI Whisper (runs locally, no API keys).

## When to Use This Skill

- User has an audio file and wants text output
- Voice note transcription
- Meeting/interview transcription
- Extracting speech from video files (ffmpeg extracts audio automatically)
- Any audio-to-text conversion

## Commands

```bash
# Basic transcription (auto-detects language)
python3 .claude/skills/transcribe/transcribe.py /path/to/audio.wav

# Specify language (faster, skips detection)
python3 .claude/skills/transcribe/transcribe.py /path/to/audio.wav -l en

# Use a larger model for better accuracy
python3 .claude/skills/transcribe/transcribe.py /path/to/audio.wav -m base

# Output to file instead of stdout
python3 .claude/skills/transcribe/transcribe.py /path/to/audio.wav -o transcript

# With timestamps
python3 .claude/skills/transcribe/transcribe.py /path/to/audio.wav -t

# List available models
python3 .claude/skills/transcribe/transcribe.py --list-models
```

## Options

- First positional arg: path to audio file (required)
- `-m`, `--model`: whisper model (default: `large`)
- `-l`, `--language`: language code, e.g. `en`, `ar`, `de` (default: auto-detect)
- `-o`, `--output`: save transcript to file (without extension, saves as .txt)
- `-t`, `--timestamps`: include timestamps in output

## Models

| Model | Size | Speed | Accuracy |
|-------|------|-------|----------|
| `tiny` | 39 MB | Fastest | Good for clear speech |
| `base` | 74 MB | Fast | Good default |
| `small` | 244 MB | Medium | Better accuracy |
| `medium` | 769 MB | Slow | High accuracy |
| `large` | 1.5 GB | Slowest | Best accuracy |

## Supported Formats

Any format ffmpeg supports: wav, mp3, m4a, mp4, webm, ogg, flac, etc.

## Output

Default: prints transcript to stdout (Claude reads it directly).
With `-o`: saves to `.claude/skills/transcribe/output/{name}.txt`

## After Transcribing

1. Show the transcript text to the user
2. If saved to file, present the file path (renders as clickable pill in iOS)
