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
- Vague prompts like "make it better" -- be specific
- Extremely long prompts -- Gemini works best with concise, clear descriptions
- Conflicting instructions -- "photorealistic cartoon" confuses the model

## After Generating

1. Read the output image to evaluate quality
2. If it needs adjustments, re-run with a refined prompt or use --edit on the result
3. Present the full output path to the user (renders as a clickable file pill in iOS)

## Output

Default output: `.claude/skills/image/output/misc/`

Files are named `{output}.{ext}` where ext matches what Gemini returns (usually png).

## Animation (Veo + Background Removal)

Animate a static image into a looping GIF/video using Google Veo for video generation and background removal for transparency.

### Full Pipeline (Proven)

1. Place character on **magenta (#FF00FF)** canvas at 1280x720 (Veo's 16:9)
2. Send to Veo for 4s video generation (use latest: `veo-3.1-generate-preview` or `veo-3.1-fast-generate-preview`)
3. Extract frames: `ffmpeg -i video.mp4 /tmp/frames/frame-%04d.png`
4. Remove background per frame (see Background Removal below)
5. Crop all frames with a **single union bounding box** (NOT per-frame crop -- that causes jitter)
6. Assemble GIF + optimize with gifsicle

### Background Removal

This is the hardest part of the pipeline. We tested extensively. The right approach depends on what you're removing backgrounds from.

#### For pixel art / hard-edge characters: Hybrid Color Key (BEST)

ML models are designed for photos, not pixel art. A color-based approach is better for hard edges. But pure color keying can eat character pixels that happen to share the bg color. The solution: **Apple Vision mask to protect the character + aggressive color key to remove the background + color replacement for fringe pixels**.

```python
from PIL import Image
import numpy as np
from scipy import ndimage

img = Image.open('frame.png').convert('RGBA')
vision = Image.open('vision-mask.png').convert('RGBA')  # from Vision tool

data = np.array(img, dtype=np.float32)
vision_data = np.array(vision)
foreground = vision_data[:,:,3] > 128

r, g, b = data[:,:,0], data[:,:,1], data[:,:,2]
magenta = (r / 255.0) * (1.0 - g / 255.0) * (b / 255.0)
green = (1.0 - r / 255.0) * (g / 255.0) * (1.0 - b / 255.0)

# Step 1: remove everything outside Vision's foreground
data[~foreground] = [0, 0, 0, 0]

# Step 2: fix magenta/green fringe pixels INSIDE foreground
# by replacing their color with nearest clean neighbor average
bad_inside = foreground & ((magenta > 0.15) | (green > 0.15))
clean_fg = foreground & (magenta <= 0.15) & (green <= 0.15)

if bad_inside.any() and clean_fg.any():
    for ch in range(3):
        channel = data[:,:,ch].copy()
        kernel = np.ones((5,5)) / 25
        clean_vals = channel * clean_fg
        clean_count = np.maximum(ndimage.convolve(clean_fg.astype(float), kernel), 1e-10)
        smoothed = ndimage.convolve(clean_vals, kernel) / clean_count
        data[bad_inside, ch] = smoothed[bad_inside]

result = Image.fromarray(data.astype(np.uint8))
```

**Apple Vision mask generation** (compile once, reuse forever):
```bash
# Compile the Vision bg removal tool
swiftc -o /tmp/vision_remove_bg /tmp/vision_remove_bg.swift -framework Vision -framework CoreImage -framework AppKit

# Use per frame
/tmp/vision_remove_bg input.png output.png
```

The Swift source for the Vision tool is at `/tmp/vision_remove_bg.swift`. It uses `VNGenerateForegroundInstanceMaskRequest` which runs on the Neural Engine -- fast and free.

#### For photos / complex subjects: ML models

| Model | Speed | Quality | Notes |
|-------|-------|---------|-------|
| rembg (default u2net) | 0.8s/frame | Good | Best speed/quality tradeoff |
| rembg (BiRefNet) | 16s/frame | Great | `new_session("birefnet-general")`, too slow for batch |
| Apple Vision | ~0.5s/frame | Great | Neural Engine, no pip deps, best for batch |
| remove.bg API | instant | Perfect | 50 free/month, best edge handling, costs money |

**Key finding**: All ML models (rembg, BiRefNet, Apple Vision) produce nearly identical results on the same input. The differences are marginal. For photos they all work well. For pixel art they all fail the same way -- they can't distinguish "white background" from "white pixel that's part of the character." That's why the hybrid color key approach exists.

#### What NOT to do

- **Don't use rembg on pixel art with white/light elements** -- it eats the white parts of the character (eyes, highlights, paintbrush tips)
- **Don't autocrop each frame independently** -- the bounding box shifts per frame causing jitter. Compute the union bbox across ALL frames, then crop every frame with that single box
- **Don't assume Veo keeps your background color** -- Veo can change background color mid-video (e.g. magenta for first half, green for second half). Always handle multiple bg colors
- **Don't use ffmpeg chromakey on video-compressed frames** -- video compression creates anti-aliased edges that blend the bg color into the character outline. A tolerance-based approach (magenta score > threshold) handles this better than exact color matching

### Background Color Choice

| Color | Pros | Cons |
|-------|------|------|
| **Magenta (#FF00FF)** | Zero overlap with most characters, easy to detect | Veo sometimes shifts to green mid-video |
| Green (#00FF00) | Traditional green screen | Overlaps with any green in the character |
| White (#FFFFFF) | Clean for ML models | ML can't distinguish white bg from white character parts |
| Blue (#0000FF) | Low overlap with warm characters | Can overlap with blue elements |

**Winner: Magenta** -- but always also handle green as a fallback since Veo can switch colors.

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
    model="veo-3.1-generate-preview",
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

### GIF Assembly

```python
from PIL import Image
import os

# Load transparent frames, compute UNION bounding box
frames = [Image.open(f) for f in sorted(frame_files)]
min_x, min_y, max_x, max_y = 9999, 9999, 0, 0
for f in frames:
    bbox = f.getbbox()
    if bbox:
        min_x, min_y = min(min_x, bbox[0]), min(min_y, bbox[1])
        max_x, max_y = max(max_x, bbox[2]), max(max_y, bbox[3])

# Crop ALL frames with the SAME box (prevents jitter)
cropped = [f.crop((min_x, min_y, max_x, max_y)) for f in frames]

# Save
cropped[0].save("raw.gif", save_all=True, append_images=cropped[1:],
                loop=0, duration=42, disposal=2)
```

```bash
# Optimize with gifsicle (requires: brew install gifsicle)
gifsicle -O3 --lossy=30 --colors 128 raw.gif -o optimized.gif
```

Typical sizes: 192 frames (8s@24fps) = 1-2MB optimized. Reduce frames (every Nth) for smaller files.

### remove.bg API

API keys in `habibi/.env` (`REMOVEBG_API_KEY` and `REMOVEBG_API_KEY_ALT`). 50 free credits/month per key. Best absolute quality but limited credits. Save for final output, not iteration.
