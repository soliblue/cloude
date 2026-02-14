# Local Music Generation Skill

## Summary
`/music` skill using Meta's MusicGen small (300M params) to generate background music locally. Same auto-setup pattern as `/speak` — venv + model download on first run.

## Use Case
- Daily recap background tracks (unique 30s song every day)
- Video soundtracks
- Ambient music generation

## Implementation
- `skills/music/generate.py` — self-contained Python script
- `facebook/musicgen-small` via HuggingFace transformers
- Auto-creates venv, installs deps, downloads ~2GB model on first run
- Text prompt → WAV file
- Mood presets: ambient, upbeat, cinematic, chill, dark, happy, focus, recap
- `-d` flag for duration (default 10s, recap uses 30s)

## Performance
- ~30s generation per 10s of audio on Apple Silicon CPU
- ~90s for a 30s recap track
- First run: ~5 min (venv + model download)

## Testing
- [ ] First run auto-setup works
- [ ] 10s generation with custom prompt
- [ ] 30s recap-length generation
- [ ] Mood presets work
- [ ] Output plays correctly
- [ ] Recap integration (ffmpeg mix with narration)
