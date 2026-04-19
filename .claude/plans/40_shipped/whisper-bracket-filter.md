---
title: "Whisper Bracket Filter"
description: "Replaced hardcoded bracket annotation checks with a regex to strip all [BLANK_AUDIO], [MUSIC], etc. from Whisper output."
created_at: 2026-02-07
tags: ["input", "agent"]
icon: waveform.slash
build: 43
---


# Whisper Bracket Filter
## Summary
Filter out all `[...]` bracket annotations from Whisper transcription output, not just `[BLANK_AUDIO]` and `[silence]`.

## Problem
Whisper produces various bracket annotations like `[BLANK_AUDIO]`, `[MUSIC]`, `[LAUGHTER]`, `[inaudible]`, etc. We were only filtering specific ones, letting others leak into transcription results.

## Solution
Replace the hardcoded string checks with a regex `\[.*?\]` that strips all bracket annotations, then trim whitespace.

## Files Changed
- `Cloude/Cloude Agent/Services/WhisperService.swift` — replaced specific `[BLANK_AUDIO]`/`[silence]` checks with regex removal of all `[...]` patterns
