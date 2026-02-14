#!/bin/bash
RECAP=/Users/soli/Desktop/CODING/cloude/.claude/skills/video/output/daily-short-v3
SPEAK=/Users/soli/Desktop/CODING/cloude/.claude/skills/speak/output

ffmpeg -y \
  -i "$RECAP/recap-silent.mp4" \
  -i "$SPEAK/narr-01-title.wav" \
  -i "$SPEAK/narr-02-roster.wav" \
  -i "$SPEAK/narr-03-moodboards.wav" \
  -i "$SPEAK/narr-04-invaders.wav" \
  -i "$SPEAK/narr-05-kart.wav" \
  -i "$SPEAK/narr-06-fighter.wav" \
  -i "$SPEAK/narr-07-zelda.wav" \
  -i "$SPEAK/narr-08-tetris.wav" \
  -i "$SPEAK/narr-09-ddr.wav" \
  -i "$SPEAK/narr-10-end.wav" \
  -filter_complex \
"[1:a]adelay=300|300,aformat=sample_rates=44100:channel_layouts=stereo[a1];
[2:a]adelay=2200|2200,aformat=sample_rates=44100:channel_layouts=stereo[a2];
[3:a]adelay=4000|4000,aformat=sample_rates=44100:channel_layouts=stereo[a3];
[4:a]adelay=7600|7600,aformat=sample_rates=44100:channel_layouts=stereo[a4];
[5:a]adelay=10100|10100,aformat=sample_rates=44100:channel_layouts=stereo[a5];
[6:a]adelay=12600|12600,aformat=sample_rates=44100:channel_layouts=stereo[a6];
[7:a]adelay=15100|15100,aformat=sample_rates=44100:channel_layouts=stereo[a7];
[8:a]adelay=17600|17600,aformat=sample_rates=44100:channel_layouts=stereo[a8];
[9:a]adelay=20100|20100,aformat=sample_rates=44100:channel_layouts=stereo[a9];
[10:a]adelay=22600|22600,aformat=sample_rates=44100:channel_layouts=stereo[a10];
[a1][a2][a3][a4][a5][a6][a7][a8][a9][a10]amix=inputs=10:duration=longest:dropout_transition=0,volume=10[aout]" \
  -map 0:v -map "[aout]" \
  -c:v copy -c:a aac -b:a 128k -shortest \
  "$RECAP/recap-2026-02-11.mp4"
