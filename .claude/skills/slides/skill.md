---
name: slides
description: Create presentation slides with AI image generation and assemble them into a deck.
user-invocable: true
metadata:
  icon: rectangle.stack.fill
  aliases: [presentation, deck, ppt]
---

# Slides

Create slide decks by generating slide images iteratively, then assembling them into PowerPoint if needed.

## Workflow

### 1. Plan
- define the slide list
- agree on style and branding
- decide whether to use reference images

### 2. Generate
- make one slide at a time
- show the output path
- get feedback
- regenerate until approved

### 3. Assemble
- combine approved slides into a `.pptx` when requested

## Output

Slides go to `.claude/skills/slides/slides/output/`.

## Setup

```bash
source .claude/skills/slides/.venv/bin/activate 2>/dev/null ||   (cd .claude/skills/slides && python -m venv .venv && source .venv/bin/activate && pip install -q google-genai pillow python-dotenv python-pptx)
source .claude/skills/slides/.env
```

## Generate a Slide

Use `.claude/skills/slides/slides/generate.py` when possible, or the existing inline generation pattern in this folder.
Always save each slide as a separate image and show the path to the user.

## Assemble a Deck

Use `python-pptx` to combine approved slide images into a `.pptx`.

## Rules

- Iterate one slide at a time.
- Prefer reference images for consistency.
- Keep prompts specific.
- Keep slides visually simple.
- Use clickable file paths so the user can preview each slide.
