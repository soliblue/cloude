---
name: recap
description: Generate a daily recap video from today's work — Sora videos, Gemini images, app screenshots, everything. Stitches the full day into a ~30s cinematic short.
user-invocable: true
disable-model-invocation: true
icon: film.stack
aliases: [daily short, daily recap, story]
---

# Daily Recap Skill

Generate a ~30-second recap video from the FULL day — Gemini images, Sora videos, app screenshots, storyboards, everything visual. Tells the story of what happened, not just a clip reel.

## When to Use

- End of a session where videos or images were generated
- User asks for a "daily short", "recap", "story", or "what did we make today"
- After experiments, creative sessions, or any visual work

## How It Works

### 1. Collect ALL Assets

Scan everything from today. Cast a wide net:

```bash
# Sora videos
ls -lt skills/video/output/*.mp4 | head -40

# Gemini images (mood boards, story frames, references, icons)
ls -lt .claude/skills/image/output/*.{jpg,png} | head -30

# App screenshots
find . -name "screenshot*" -o -name "Screenshot*" | grep -v node_modules | grep -v .git

# Review frames from experiments
ls skills/video/output/exp*-review/*.jpg 2>/dev/null

# Any other visual artifacts
find . -name "*.png" -newer <start_of_day> -not -path "*/node_modules/*" -not -path "*/.git/*" | head -20
```

### 2. Build a Story Arc

This is NOT just a clip reel. Arrange assets into a narrative:

**Act 1 — Creation** (images): mood boards, reference art, concept frames, story scenes. The raw materials. Use 1-1.5s per image. Fast cuts.

**Act 2 — Animation** (videos): the best Sora results. What came alive. Use 2-2.5s per clip. Let motion breathe. Add poetic labels ("It moves.", "It rises.", "It blinks.") for the best moments.

**Act 3 — Context** (app/screenshots): the product, storyboards, comparisons. Why this all matters. Use 1-1.5s per image.

**Bookends**: title card (2s) + end card with stats (3s).

### 3. Pick 12-16 Highlights

Target ~30s total. Budget:
- Title: 2s
- Act 1 (images): 4-6 clips × 1.5s = 6-9s
- Act 2 (videos): 5-7 clips × 2-2.5s = 10-17s
- Act 3 (context): 2-3 clips × 1.5s = 3-4.5s
- End card: 3s

Prioritize:
- **Variety** — different styles, scenes, experiments
- **Visual impact** — most impressive or surprising results
- **Story** — arrange so it builds toward a payoff
- **The stunner** — every recap needs one "wow" moment (e.g. coffee shop steam, cloud rising)

### 4. Build Each Clip

All clips: **1080x1920 portrait, 30fps, no audio, H.264.**

#### Title Card (2s)
```bash
ffmpeg -y -f lavfi -i "color=c=black:s=1080x1920:r=30:d=2" \
  -vf "drawtext=fontfile=/System/Library/Fonts/Helvetica.ttc:text='DAY IN THE LAB':fontsize=72:fontcolor=white:x=(w-text_w)/2:y=(h-text_h)/2-60,drawtext=fontfile=/System/Library/Fonts/Helvetica.ttc:text='Feb 9, 2026':fontsize=36:fontcolor=0xAAAAAA:x=(w-text_w)/2:y=(h-text_h)/2+40" \
  -c:v libx264 -pix_fmt yuv420p title.mp4
```

#### Video Clip (2-2.5s, trimmed from Sora output)
```bash
ffmpeg -y -i input.mp4 -t 2.5 -an \
  -vf "scale=1080:1920:force_original_aspect_ratio=decrease,pad=1080:1920:(ow-iw)/2:(oh-ih)/2:black,drawtext=fontfile=/System/Library/Fonts/Helvetica.ttc:text='Label':fontsize=32:fontcolor=white:borderw=2:bordercolor=black:x=(w-text_w)/2:y=h-80" \
  -c:v libx264 -pix_fmt yuv420p -r 30 clip.mp4
```

#### Static Image (1-1.5s)
```bash
ffmpeg -y -loop 1 -i image.jpg -t 1.5 \
  -vf "scale=1080:1920:force_original_aspect_ratio=decrease,pad=1080:1920:(ow-iw)/2:(oh-ih)/2:black,drawtext=fontfile=/System/Library/Fonts/Helvetica.ttc:text='Label':fontsize=32:fontcolor=white:borderw=2:bordercolor=black:x=(w-text_w)/2:y=h-80" \
  -c:v libx264 -pix_fmt yuv420p -r 30 clip.mp4
```

#### Poetic Label (for standout moments)
Use larger font, no "Label:" prefix — just the feeling:
```bash
drawtext=...text='It moves.':fontsize=36:fontcolor=white:borderw=2:bordercolor=black:x=(w-text_w)/2:y=h-80
```

#### End Card (3s, with stats)
```bash
ffmpeg -y -f lavfi -i "color=c=black:s=1080x1920:r=30:d=3" \
  -vf "drawtext=...:text='84 videos':fontsize=48:...:y=(h-text_h)/2-120,\
       drawtext=...:text='14 images':fontsize=48:...:y=(h-text_h)/2-50,\
       drawtext=...:text='9 experiments':fontsize=48:...:y=(h-text_h)/2+20,\
       drawtext=...:text='0 credits left':fontsize=48:fontcolor=0xFF6666:...:y=(h-text_h)/2+90,\
       drawtext=...:text='cloude.app':fontsize=28:fontcolor=0x666666:...:y=(h-text_h)/2+180" \
  -c:v libx264 -pix_fmt yuv420p end.mp4
```

### 5. Stitch (silent version)

```bash
# Number clips 00-XX for sort order
# Create concat list with absolute paths
ls -1 clips/[0-9]*.mp4 | sort | while read f; do
  echo "file '$(pwd)/$f'"
done > concat.txt

# Final stitch (silent)
ffmpeg -y -f concat -safe 0 -i concat.txt \
  -c:v libx264 -pix_fmt yuv420p -r 30 -movflags +faststart \
  recap-silent.mp4
```

### 6. Add Narration

Write a short narration script (~8 lines) that matches the visual pacing. Each line maps to a section of the video timeline.

**Script guidelines:**
- Short, rhythmic sentences. Poetic, not explanatory.
- Title: 1 line. Acts: 1-2 lines each. End card: 1 line with stats.
- Total speech should fit within the video duration with breathing room.

**Generate segments with Kokoro TTS:**
```bash
python3 skills/speak/generate.py "Day in the lab." -v bf_emma -s 0.95 -o narr-01-title
python3 skills/speak/generate.py "Started with mood boards." -v bf_emma -s 0.95 -o narr-02-act1
python3 skills/speak/generate.py "Then Sora brought them to life." -v bf_emma -s 0.95 -o narr-03-act2
# ... one segment per narrative beat
```

Voice: `bf_emma` (UK Female) at 0.95x speed works well for calm narration. Adjust voice/speed per session mood.

**Mix narration into video with timed placement:**
```bash
ffmpeg -y \
  -i recap-silent.mp4 \
  -i skills/speak/output/narr-01-title.wav \
  -i skills/speak/output/narr-02-act1.wav \
  -i skills/speak/output/narr-03-act2.wav \
  ... \
  -filter_complex "\
[1:a]adelay=300|300,aformat=sample_rates=44100:channel_layouts=stereo[a1];\
[2:a]adelay=2000|2000,aformat=sample_rates=44100:channel_layouts=stereo[a2];\
[3:a]adelay=5000|5000,aformat=sample_rates=44100:channel_layouts=stereo[a3];\
...\
[a1][a2][a3]...amix=inputs=N:duration=longest:dropout_transition=0,volume=N[aout]" \
  -map 0:v -map "[aout]" \
  -c:v copy -c:a aac -b:a 128k -shortest \
  recap-YYYY-MM-DD.mp4
```

**Key:** `adelay=MS|MS` places each segment at the right millisecond. Calculate from cumulative clip durations. `volume=N` (where N = number of inputs) compensates for amix normalization.

### 7. Output

Save to: `skills/video/output/daily-short-v3/`
Filename: `recap-YYYY-MM-DD.mp4`
Keep previous versions — never overwrite.

## Key Details

- **Always strip audio** (`-an`) from Sora clips — speech hallucination
- **Portrait 1080x1920** — mobile-first, social-ready
- **Labels at bottom** — `y=h-80` stays out of main content
- **Black letterboxing** — `pad` handles mixed aspect ratios
- **30 fps** — consistent across all clips
- **Border on text** (`borderw=2:bordercolor=black`) for readability over any background
- **Narration with Kokoro TTS** — `bf_emma` voice, 0.95x speed, one WAV per narrative beat
- **adelay for timing** — place each narration segment at exact millisecond offset
- **volume=N compensation** — amix divides volume by input count, multiply back
- **Images go FAST** (1-1.5s), videos go SLOWER (2-2.5s) — let motion breathe
- **Poetic labels** on the best moments — "It moves.", "It rises.", "It blinks."
- **End card stats** — count everything: videos, images, experiments, credits spent

## Example Story Arcs

### Sora Experiment Day
Title → mood boards → story frames → "It moves." (first animation) → best experiments → app screenshot → storyboard → stats

### UI Polish Session
Title → before screenshots → code changes (terminal) → after screenshots → side-by-side → deploy → stats

### Creative Session
Title → reference images → generation attempts → best results → final picks → stats
