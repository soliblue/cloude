---
name: image
description: Generate images using Gemini, and animate them with Veo. Use for illustrations, mockups, photos, diagrams, art, visual references, and character animations.
user-invocable: true
icon: paintbrush.pointed.fill
aliases: [paint, draw, img, generate image, animate]
parameters:
  - name: description
    placeholder: Describe the image or animation...
    required: true
---

# Image Generation Skill

Generate images using Gemini's native image generation. For app icons (bg removal + iOS asset pipeline), use the icon script at `.claude/skills/image/icon/generate.py`.

## When to Use This Skill

Generate an image when:
- User describes something visual (UI concept, scene, object) and a reference image would help
- A social media post or article would benefit from an accompanying visual
- User asks for a mockup, wireframe, or design reference
- Explaining a concept where a diagram or illustration clarifies better than words
- Any creative task where showing beats telling
- User explicitly asks for an image, drawing, illustration, or photo

Do NOT use this skill when:
- Generating app icons via pure text-to-image. Use `.claude/skills/image/icon/generate.py` instead (bg removal + iOS asset pipeline).
- The user needs code, not visuals
- A text description is sufficient and the user hasn't asked for an image

## Commands

```bash
source .env

# Text-to-image
GOOGLE_API_KEY=$GOOGLE_API_KEY .claude/skills/image/generate.sh \
  --prompt "description of image" \
  --output my-image

# Edit an existing image
GOOGLE_API_KEY=$GOOGLE_API_KEY .claude/skills/image/generate.sh \
  --prompt "change the sky to sunset colors" \
  --edit /path/to/existing-image.png \
  --output edited-image

# With aspect ratio
GOOGLE_API_KEY=$GOOGLE_API_KEY .claude/skills/image/generate.sh \
  --prompt "wide landscape photo of mountains" \
  --aspect "16:9" \
  --output landscape

# Transparent PNG (bg removal + autocrop)
GOOGLE_API_KEY=$GOOGLE_API_KEY .claude/skills/image/generate.sh \
  --prompt "pixel art character holding a sword" \
  --transparent \
  --output character

# Custom output directory
GOOGLE_API_KEY=$GOOGLE_API_KEY .claude/skills/image/generate.sh \
  --prompt "diagram of system architecture" \
  --output-dir /path/to/destination \
  --output arch-diagram
```

## Options

- `--prompt` - What to generate (required)
- `--output` - Filename without extension (default: image-TIMESTAMP)
- `--edit` - Path to existing image to modify (sends image + prompt together)
- `--aspect` - Aspect ratio hint: "16:9", "9:16", "square", "portrait", "landscape"
- `--grid` - Generate multiple images in one call: "2x2" (4 images) or "3x3" (9 images)
- `--transparent` - Remove background after generation (uses rembg). Adds "solid white background" to prompt, then removes it with BiRefNet + autocrop. Output is always PNG.
- `--output-dir` - Where to save (default: .claude/skills/image/output/misc/)
- `--model` - Gemini model override (default: gemini-2.0-flash-exp)

## Grid Mode (Multiple Images)

Generate 4 or 9 variations in a single API call using `--grid`:

```bash
source .env

# 4 variations (2x2 grid)
GOOGLE_API_KEY=$GOOGLE_API_KEY .claude/skills/image/generate.sh \
  --prompt "cute robot mascot in different poses" \
  --grid 2x2 \
  --output robot

# 9 variations (3x3 grid)
GOOGLE_API_KEY=$GOOGLE_API_KEY .claude/skills/image/generate.sh \
  --prompt "abstract pattern in different color palettes" \
  --grid 3x3 \
  --output pattern
```

This creates a grid template, sends it to Gemini asking it to fill each cell, then crops the output into individual images (`robot-1.png`, `robot-2.png`, etc.). One API call instead of 4 or 9.

## Prompt Tips for Gemini

**What works well:**
- Be specific about style: "watercolor illustration", "flat vector", "photorealistic", "pixel art"
- Describe composition: "close-up", "bird's eye view", "centered on white background"
- Mention lighting: "soft natural light", "dramatic shadows", "backlit"
- Specify mood: "warm and inviting", "dark and moody", "clean and minimal"

**For image editing (--edit):**
- Be clear about what to change: "make the background blue" not just "change it"
- Reference specific elements: "remove the person on the left", "add clouds to the sky"
- Style transfer works: "make this look like a watercolor painting"

**What to avoid:**
- Vague prompts like "make it better" — be specific
- Extremely long prompts — Gemini works best with concise, clear descriptions
- Conflicting instructions — "photorealistic cartoon" confuses the model

## After Generating

1. Read the output image to evaluate quality
2. If it needs adjustments, re-run with a refined prompt or use --edit on the result
3. Present the full output path to the user (renders as a clickable file pill in iOS)

## Output

Default output: `.claude/skills/image/output/misc/`

Files are named `{output}.{ext}` where ext matches what Gemini returns (usually png).

## Animation (Veo + Background Removal)

Animate a static image into a looping GIF/video using Google Veo for video generation and background removal for transparency.

### High-Level Pipeline

There are two approaches to animate a character:

**Approach A: Green screen + ffmpeg chromakey** (fast, good for simple shapes)
1. Place character on `#00FF00` green canvas (match Veo's aspect ratio - 16:9 = 1280x720)
2. Send to Veo for video generation
3. `ffmpeg -vf "chromakey=0x00FF00:0.25:0.08,format=rgba"` to remove green
4. Crop + optimize with gifsicle

**Approach B: Green screen + per-frame AI bg removal** (slower, cleaner edges)
1. Place character on `#00FF00` green canvas (match Veo's aspect ratio)
2. Send to Veo for video generation
3. Extract frames: `ffmpeg -i video.mp4 /tmp/frames/frame-%04d.png`
4. Remove background per frame using AI model (see Background Removal below)
5. Crop + optimize with gifsicle

**When to use which:**
- **Approach A** (chromakey): Fast, works well when character has no green and edges are clean. Can leave slight green fringe on anti-aliased edges.
- **Approach B** (AI removal): Slower (0.8s/frame with rembg default) but handles complex edges, hair, transparency perfectly. Use when chromakey leaves artifacts.

### Background Removal Options

**Local models** (free, offline):
- `rembg` default model - 0.8s/frame, good quality, best speed/quality tradeoff
- `rembg` with BiRefNet (`new_session("birefnet-general")`) - 16s/frame, highest quality, use for final output
- `transparent-background` (InSPyReNet) - alternative, similar quality to rembg

**Online APIs** (better edge quality, costs money):
- remove.bg - industry standard, 50 free/month, best edge handling
- withoutBG - open source + hosted API, 50 free credits
- Clipdrop - good precision, has API

**ffmpeg chromakey** (instant, no ML):
- `chromakey=0x00FF00:similarity:blend` - similarity 0.25, blend 0.08 works well
- Best for solid green backgrounds, no per-frame cost
- Can chain: `chromakey=green,chromakey=black` but careful with character outlines

### Veo API Reference

**Available models**:
- `veo-2.0-generate-001`
- `veo-3.0-generate-001` / `veo-3.0-fast-generate-001`
- `veo-3.1-generate-preview` / `veo-3.1-fast-generate-preview`

**Aspect ratios**: Only `16:9` (default) and `9:16`. No 1:1.

**Duration**: 4, 6, or 8 seconds (`duration_seconds` parameter). Min is 4s.

**GenerateVideosConfig parameters**: `aspect_ratio`, `number_of_videos`, `duration_seconds`, `fps`, `resolution` ("720p", "1080p", "4k"), `seed`

**Image-to-video example**:
```python
from google import genai
from google.genai import types
import time, httpx

client = genai.Client(api_key="YOUR_KEY")

img_bytes = open("input.png", "rb").read()
image = types.Image(image_bytes=img_bytes, mime_type="image/png")

operation = client.models.generate_videos(
    model="veo-3.0-generate-001",
    prompt="Description of the animation...",
    image=image,
    config=types.GenerateVideosConfig(
        duration_seconds=4,
        number_of_videos=1,
    ),
)

while not operation.done:
    time.sleep(10)
    operation = client.operations.get(operation)

for vid in operation.result.generated_videos:
    url = vid.video.uri + "&key=YOUR_KEY"
    resp = httpx.get(url, follow_redirects=True)
    with open("output.mp4", "wb") as f:
        f.write(resp.content)
```

**Key notes**:
- `types.Image` requires both `image_bytes` and `mime_type`
- Download requires appending `&key=` to the video URI (auth not included automatically)
- Input image should match the output aspect ratio (16:9 = 1280x720, 9:16 = 720x1280) to avoid black bars
- For looping: prompt with "seamless loop where first and last frames are identical"

### GIF Optimization

After extracting transparent frames:
```bash
# Assemble GIF from frames (PIL)
frames[0].save("raw.gif", save_all=True, append_images=frames[1:], loop=0, duration=42, disposal=2)

# Optimize with gifsicle (requires: brew install gifsicle)
gifsicle -O3 --lossy=30 --colors 128 raw.gif -o optimized.gif
```

Typical sizes: 192 frames (8s@24fps) = 2-4MB optimized. Reduce frames (every Nth) for smaller files.
