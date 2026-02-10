---
name: video
description: Generate videos using Sora. Text-to-video and image-to-video via Soli's ChatGPT Pro subscription.
user-invocable: true
icon: film.fill
aliases: [sora, generate video, vid]
parameters:
  - name: prompt
    placeholder: Describe the video...
    required: true
---

# Video Generation Skill

Generate videos using OpenAI's Sora via Playwright automation. Supports text-to-video and image-guided generation.

## When to Use This Skill

- User asks for a video, animation, or motion content
- A concept would be better shown as video than a still image
- User explicitly mentions Sora
- Image-to-video: user provides a reference image and wants it animated

Do NOT use when:
- A still image is sufficient (use the `image` skill instead)
- User needs code or text, not visuals

## Commands

```bash
# Text-to-video (landscape, 5 seconds)
python3 /Users/soli/Desktop/CODING/cloude/.claude/skills/video/create.py "a goldfish swimming in clear water"

# Portrait orientation
python3 /Users/soli/Desktop/CODING/cloude/.claude/skills/video/create.py "a person walking through rain" -o portrait

# Square
python3 /Users/soli/Desktop/CODING/cloude/.claude/skills/video/create.py "abstract shapes morphing" -o square

# Longer duration (10s = 300 frames, 15s = 450, 20s = 600)
python3 /Users/soli/Desktop/CODING/cloude/.claude/skills/video/create.py "timelapse of clouds" -f 300

# Image-to-video (animate a reference image)
python3 /Users/soli/Desktop/CODING/cloude/.claude/skills/video/create.py "camera slowly zooms out" --image /path/to/photo.png

# Larger resolution (512x896 portrait, 1024x576 landscape)
python3 /Users/soli/Desktop/CODING/cloude/.claude/skills/video/create.py "epic landscape" -s large

# Batch mode (submit multiple jobs in one browser session)
python3 /Users/soli/Desktop/CODING/cloude/.claude/skills/video/create.py --batch /path/to/jobs.json
```

## Options

- First positional arg: prompt (required, unless using --batch)
- `-o`, `--orientation`: `landscape` (default), `portrait` (square is NOT supported by Sora)
- `-s`, `--size`: `small` (default), `large`
- `-f`, `--frames`: `150` (5s, default), `300` (10s), `450` (15s), `600` (20s)
- `-i`, `--image`: path to reference image for image-to-video generation
- `-b`, `--batch`: path to JSON file with array of jobs

## Batch Mode

Submit multiple videos in a single browser session. Write a JSON file with an array of jobs:

```json
[
  {"prompt": "first video prompt", "orientation": "portrait"},
  {"prompt": "second video", "image": "/path/to/ref.png", "frames": 300},
  {"prompt": "third video", "orientation": "square", "size": "large"}
]
```

Each job supports: `prompt` (required), `orientation`, `size`, `frames`, `image` (all optional).

All jobs are submitted at once, polled together, and downloaded when ready. Much faster than running one at a time.

## Multi-Scene Story Workflow (Mood Board Chaining)

For multi-scene videos with consistent visual style, use this Gemini→Gemini→Sora pipeline:

### Step 1: Mood Board
Generate 2-3 mood boards with the `image` skill to establish the visual identity. Include color palette, key elements, atmosphere, character design. Present to user for approval.

### Step 2: Chained Frame Generation
Generate each scene frame with Gemini, chaining the previous frame as reference:
- **Frame 1**: mood board (--edit) + scene 1 prompt → Gemini
- **Frame 2**: frame 1 output (--edit) + scene 2 prompt + "match the visual style of the reference" → Gemini
- **Frame 3**: frame 2 output (--edit) + scene 3 prompt + same style instruction → Gemini
- ...each frame uses the PREVIOUS frame as --edit reference

The mood board is the anchor preventing style drift. The previous frame gives scene continuity. Always include "Match the visual style of the reference image exactly. Same color palette, same pixel art fidelity, same lighting approach." in every prompt.

### Step 3: Composite Review
Build a single composite image with all frames for efficient review:
```python
from PIL import Image
frames = [Image.open(f'frame-{i}.jpg') for i in range(1, N+1)]
target_h = 400
frames = [f.resize((int(f.width * target_h/f.height), target_h), Image.LANCZOS) for f in frames]
padding = 8
comp = Image.new('RGB', (sum(f.width for f in frames) + padding*(len(frames)+1), target_h + padding*2), (20,20,30))
x = padding
for f in frames:
    comp.paste(f, (x, padding))
    x += f.width + padding
comp.save('storyboard.jpg', 'JPEG', quality=85)
```

### Step 4: Sora Animation
Feed each approved frame to Sora as image-to-video in a batch. Prompt only describes MOTION, not the scene content (Sora sees the image).

### Brand Alignment Tricks
When aligning with a specific brand:
- Include brand logo/colors as reference images in the mood board generation
- Build a manual collage of reference images (brand assets, color swatches, style examples) to feed alongside the mood board
- Keep the mood board as a constant anchor across all generations

## Sora Behavior Model (Experimental Findings)

### The Core Insight
Sora is a **storyteller, not an animator**. Given an image + motion prompt, it doesn't move existing elements — it reinterprets the scene through the lens of the prompt. The more motion/narrative you request, the more it invents.

### Motion Intensity Scale (image-to-video)

| Level | Prompt Type | Scene Preservation | Quality |
|-------|-----------|-------------------|---------|
| 1 - Still | "subtle breathing, faint particles" | Near-perfect | Best |
| 2 - Ambient | "rain falls, lights flicker, ripples" | Very good, minor color shift | Great |
| 2.5 - Detail | "cape flutters, eyes blink, cloud rises" | Very good | Great |
| 2.5 - Micro cam | "barely perceptible zoom in" | Very good | Great |
| 3 - Camera | "zoom out", "pan", "dolly" | **Destroyed** — scene reimagined | Broken |
| 4 - Orbit | "camera orbits around" | **Destroyed** — new scene invented | Broken |
| 5 - Action | "character flies, intense action" | **Destroyed** — new narrative created | Broken but creative |

**Safe zone: Levels 1–2.5.** The boundary is not "ambient vs everything" — it's **"effect-like motion" vs "motion requiring 3D scene understanding."** Cape flutter, rain, micro zoom, object displacement (cloud rising) = effects that work. Camera orbit, walking, flying = requires 3D understanding = breaks.

Safe at the boundary:
- Heavy ambient (intense rain, rapid flicker, strong wind particles)
- Small character details (cape flutter, eye blink)
- Micro camera ("barely perceptible zoom in")
- Simple object displacement ("cloud slowly rises upward")
- Character actions are ignored but don't destroy (head turn → nothing happens)

### Speech Hallucination
**~95% speech hallucination rate** across 30+ videos. Every prompt-based approach to prevent it fails:
- "Silent, no speech, no dialogue" — ignored
- "Ambient sounds only, no voices, no speaking characters" — ignored
- Speech content is random noise: "Thank you", "See ya!", "Really, good work", "vídeo!", etc.
- **Exception: scenes without humanoid characters** (e.g. coffee shop, objects only) sometimes produce silent audio (1/30+ was silent — a text-to-video coffee shop scene)
- **Only fix: strip audio in post** (`ffmpeg -i input.mp4 -an -c:v copy output.mp4`)
- Or replace audio entirely with music/Kokoro TTS narration

### Stochasticity
Same image + same prompt produces **visually consistent** results across 5 runs. Composition, character position, and scene layout are highly deterministic. Only minor variations in neon sign text and color temperature. Speech content varies wildly (random noise).

### Duration Scaling
- **Min duration: 5s** (150 frames). Requesting 75 frames rounds up to 150.
- **Max duration: 15s** (450 frames). Requesting 600 frames caps at 450.
- **Duration does NOT increase drift** for ambient prompts. 5s, 10s, and 15s all hold perfectly.
- Gen time scales: 5s ≈ 40s, 10s ≈ 90s, 15s ≈ 5min.

### Resolution & Orientation
API metadata reports half the actual resolution. Real values:

| Setting | Actual Resolution | File Size (5s) |
|---------|------------------|---------------|
| Portrait small | **704x1280** | ~3.6 MB |
| Portrait large | **1024x1792** | ~4.5 MB |
| Landscape small | **1280x704** | ~2.9 MB |
| Square | **Not supported** (400 error) | N/A |

- **Use portrait large for quality** — noticeably sharper, more detail in rain/neon
- Landscape crops/recomposes a portrait reference image — adds horizontal context
- All videos: h264 + aac audio track (even when "silent")

### Watermark
- `download_urls.no_watermark` always returns None
- Watermark ("Sora @solai") appears starting from mid-frames, not on first frame
- First frame ≈ reference image (no watermark)

### Prompt Wording Sensitivity
**Wording barely matters for ambient motion.** Tested 5 variations (plain, constrained, "looping ambient", negative framing, "cinemagraph") — all produced nearly identical results. The simplest prompt works just as well as complex ones. Don't overthink it.

### Text-to-Video vs Image-to-Video
Two fundamentally different modes:

| Aspect | Image-to-Video | Text-to-Video |
|--------|---------------|--------------|
| Style control | Exact (from reference) | Unreliable ("pixel art" may become 3D) |
| Camera movement | Destroys scene | Works well |
| Motion quality | Ambient only | Full cinematic |
| Speech hallucination | ~95% rate | Lower (0% on character-free scenes) |
| Best for | Animating existing art | Cinematic/atmospheric content |

**Strategy: Use image-to-video for style-exact ambient scenes. Use text-to-video for cinematic motion and character-free atmospheric content.**

### Art Style Performance (image-to-video)
All styles preserve scene with ambient prompts. But motion quality varies:

| Style | Motion Amount | Best For |
|-------|-------------|----------|
| **Pixel art / neon** | Most dramatic | Many light sources → lots to flicker |
| **Flat illustration** | Charming subtle | Eyes blink, warm light shifts |
| **Art nouveau / graphic** | Minimal | Fewer moving elements = less animation |

**Rule: styles with many light sources = better ambient animation.** Sora needs "things that can flicker."

### Prompt Template (Best Known)
```
[ambient motion description]. No new objects, preserve exact art style.
```
Note: speech constraints are useless — always strip audio. "No new objects, preserve exact art style" helps visual fidelity. Prompt complexity doesn't matter — keep it simple.

## Prompt Tips

**What works well (image-to-video):**
- **Ambient/atmospheric motion**: rain, particles, flicker, glow, breathing, ripples
- **Small character details**: cape flutter, eye blink
- **Micro camera**: "barely perceptible zoom in"
- **Simple object displacement**: "cloud slowly rises upward"
- Keep prompts short and simple — wording doesn't matter much
- Add "no new objects, preserve exact art style" for visual fidelity

**What breaks (image-to-video):**
- Full camera movement (pan, dolly, orbit) = scene reimagined
- Character locomotion (walk, fly, fight) = new narrative invented
- Complex multi-character interactions
- Rapid scene changes in a single generation
- Text or readable words (Sora struggles with text)
- Note: small character actions (head turn) are ignored but don't destroy

**For text-to-video:**
- Describe camera movement: "slow dolly forward", "aerial tracking shot"
- Specify lighting and mood: "golden hour", "neon-lit", "foggy morning"
- Be cinematic: "shallow depth of field", "anamorphic lens flare"
- Simple subjects with clear motion work best

## Known Limitations

- **One browser at a time**: Playwright uses a persistent Chrome profile, so only one Sora process can run. Use batch mode for parallelism (Sora generates up to 5 simultaneously server-side).
- **Double-run danger**: If a batch command times out in the CLI, the Sora jobs were ALREADY submitted server-side and will generate. Always check `ls -lt output/*.mp4 | head` for new files before re-running — you'll burn duplicate credits otherwise.
- **Audio (sy_8 model)**: `audio_transcript: {"text": "..."}` and `audio_caption: "string"` are accepted by the API but videos with audio never produce download URLs on the `sy_8` model. Audio appears broken — use Kokoro TTS locally instead for narration overlay.
- **Sora can't maintain consistency across clips**: Don't expect character/style consistency between separate Sora generations. Use Gemini for consistency (mood board chaining) and Sora only for animation.
- **100 credits/day**: ChatGPT Pro gives ~100 generations per day. Each batch job costs 1 credit per video.

## Setup (One-Time)

If the session expires, re-authenticate:
```bash
python3 /Users/soli/Desktop/CODING/cloude/.claude/skills/video/session.py login
# Opens Chrome, sign in to sora.chatgpt.com, type 'done'
```

## After Generating

1. The script prints the output path when done (MP4 file)
2. Present the full path to the user (renders as clickable file pill in iOS)
3. Generation takes 1-3 minutes depending on duration and size
4. Videos remaining count is printed after creation

## Output

Default output: `/Users/soli/Desktop/CODING/cloude/.claude/skills/video/output/`

Files are named `sora_{timestamp}.mp4`.
