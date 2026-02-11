---
name: image
description: Generate images using Gemini. Use for illustrations, mockups, photos, diagrams, art, visual references — anything where a picture adds value. Also edits existing images.
user-invocable: true
icon: paintbrush.pointed.fill
aliases: [paint, draw, img, generate image]
parameters:
  - name: description
    placeholder: Describe the image...
    required: true
---

# Image Generation Skill

Generate images using Gemini's native image generation. Separate from the `icon` skill — no background removal, no iOS asset pipeline. Pure image generation and editing.

## When to Use This Skill

Generate an image when:
- User describes something visual (UI concept, scene, object) and a reference image would help
- A social media post or article would benefit from an accompanying visual
- User asks for a mockup, wireframe, or design reference
- Explaining a concept where a diagram or illustration clarifies better than words
- Any creative task where showing beats telling
- User explicitly asks for an image, drawing, illustration, or photo

Do NOT use this skill when:
- Generating app icons (use the `icon` skill instead — it has bg removal + iOS asset pipeline)
- The user needs code, not visuals
- A text description is sufficient and the user hasn't asked for an image

## Commands

```bash
source /Users/soli/Desktop/CODING/cloude/.env

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
- `--output-dir` - Where to save (default: .claude/skills/image/output/)
- `--model` - Gemini model override (default: gemini-2.0-flash-exp)

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

Default output: `.claude/.claude/skills/image/output/`

Files are named `{output}.{ext}` where ext matches what Gemini returns (usually png).
