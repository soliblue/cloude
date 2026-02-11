# Speak Skill Aliases — narrate, transcribe

## Problem
The `/speak` skill name is fine for TTS, but users might think of it as "narrate" (for voiceovers) or want a "transcribe" command (speech-to-text, opposite direction). These are related but different:

- `/narrate` — alias for `/speak`, framed for longer voiceover/narration use
- `/transcribe` — new skill: speech-to-text (audio file → text)

## narrate
Simple alias addition to the speak skill's SKILL.md. No code change needed — just add `narrate` to the aliases list.

## transcribe
New skill: takes an audio file and returns text. Options:
- Whisper (local, via whisper.cpp or Python)
- Cloud API (OpenAI Whisper API, Gemini audio)
- On-device iOS (Speech framework — already on device, free)

Could be useful for: voice note transcription, meeting notes, audio content indexing.

## Priority
- `/narrate` alias: trivial, do anytime
- `/transcribe` skill: separate effort, needs design
