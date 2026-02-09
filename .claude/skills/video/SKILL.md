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
python3 /Users/soli/Desktop/CODING/cloude/skills/video/create.py "a goldfish swimming in clear water"

# Portrait orientation
python3 /Users/soli/Desktop/CODING/cloude/skills/video/create.py "a person walking through rain" -o portrait

# Square
python3 /Users/soli/Desktop/CODING/cloude/skills/video/create.py "abstract shapes morphing" -o square

# Longer duration (10s = 300 frames, 15s = 450, 20s = 600)
python3 /Users/soli/Desktop/CODING/cloude/skills/video/create.py "timelapse of clouds" -f 300

# Image-to-video (animate a reference image)
python3 /Users/soli/Desktop/CODING/cloude/skills/video/create.py "camera slowly zooms out" --image /path/to/photo.png

# Larger resolution
python3 /Users/soli/Desktop/CODING/cloude/skills/video/create.py "epic landscape" -s medium
```

## Options

- First positional arg: prompt (required)
- `-o`, `--orientation`: `landscape` (default), `portrait`, `square`
- `-s`, `--size`: `small` (default), `medium`, `large`
- `-f`, `--frames`: `150` (5s, default), `300` (10s), `450` (15s), `600` (20s)
- `-i`, `--image`: path to reference image for image-to-video generation

## Prompt Tips

**What works well:**
- Describe camera movement: "slow dolly forward", "aerial tracking shot", "close-up panning left"
- Specify lighting and mood: "golden hour", "neon-lit", "foggy morning"
- Be cinematic: "shallow depth of field", "anamorphic lens flare"
- Simple subjects with clear motion work best

**For image-to-video:**
- Describe the motion you want, not the image content (Sora already sees the image)
- "Camera slowly pulls back" or "gentle wind moves the trees" work well
- Keep prompts short — the image provides most of the context

**What to avoid:**
- Text or readable words in video (Sora struggles with text)
- Complex multi-character interactions
- Rapid scene changes in a single generation

## Setup (One-Time)

If the session expires, re-authenticate:
```bash
python3 /Users/soli/Desktop/CODING/cloude/skills/video/session.py login
# Opens Chrome, sign in to sora.chatgpt.com, type 'done'
```

## After Generating

1. The script prints the output path when done (MP4 file)
2. Present the full path to the user (renders as clickable file pill in iOS)
3. Generation takes 1-3 minutes depending on duration and size
4. Videos remaining count is printed after creation

## Output

Default output: `/Users/soli/Desktop/CODING/cloude/skills/video/output/`

Files are named `sora_{timestamp}.mp4`.
