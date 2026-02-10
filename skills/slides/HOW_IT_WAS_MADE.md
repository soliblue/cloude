# How This Presentation Was Made

## Overview
12-slide presentation generated using Claude Code (claude-opus-4-5) + Nano Banana Pro (Google's Gemini image model), following Anthropic and Knowunity brand guidelines.

## Models Used
- **Claude Code**: `claude-opus-4-5-20251101` - Planning, scripting, prompt crafting, iteration
- **Nano Banana Pro**: `models/nano-banana-pro-preview` - Image generation via Google GenAI API

## The Process

### 1. Content Planning (Claude Code)
- Discussed presentation topics conversationally with Claude Code
- Claude captured tips and structured them into `presentation-notes.md`
- Defined 12 slide topics with titles, subtitles, and bullet points

### 2. Base Template (Nano Banana)
```python
# Started with Knowunity branded background, sent to Nano Banana to adapt
response = client.models.generate_content(
    model="models/nano-banana-pro-preview",
    contents=[prompt, Image.open("knowunity-background.png")],  # Reference image
    config=GenerateContentConfig(
        response_modalities=["IMAGE"],
        image_config=ImageConfig(aspect_ratio="16:9"),
    ),
)
```
- Iterated 4 times: fewer K logos, lighter gray, more whitespace
- Final: sparse K letterform grid on white background

### 3. Mascot Variations (Claude Code → Nano Banana)
Claude Code wrote detailed prompts for each mascot variation, then called Nano Banana:
```python
# Claude crafted the prompt, Nano Banana generated the image
MASCOT_PROMPT = """
Generate an illustration of the Claude Code mascot as a military general...
Standing FRONT AND CENTER, behind it rows of smaller Claude mascots...
"""

response = client.models.generate_content(
    model="models/nano-banana-pro-preview",
    contents=[MASCOT_PROMPT, Image.open("claude-mascot.png")],  # Reference
    config=GenerateContentConfig(
        response_modalities=["IMAGE"],
        image_config=ImageConfig(aspect_ratio="1:1"),
    ),
)
```
Generated 12 variations: teacher, conductor, graduate, general, scientist, judge, mirror, assistant, builder, relaxed, questions.

### 4. Full Slide Generation (Nano Banana with multiple references)
Combined 3 inputs per slide:
1. Base template image (K logo background)
2. Mascot variation image
3. Text prompt with title, subtitle, layout instructions

```python
response = client.models.generate_content(
    model="models/nano-banana-pro-preview",
    contents=[
        SLIDE_PROMPT,           # Title, subtitle, bullets, layout
        Image.open(BASE),       # Reference 1: background template
        Image.open(MASCOT),     # Reference 2: mascot for this slide
    ],
    config=GenerateContentConfig(
        response_modalities=["IMAGE"],
        image_config=ImageConfig(
            aspect_ratio="16:9",
            image_size="4K",      # High quality output
        ),
    ),
)
```

### 5. Design Guidelines (Claude Code research)
Claude Code searched for Anthropic brand guidelines and incorporated:
- Colors: `#141413` (dark), `#b0aea5` (gray), `#d97757` (orange accent)
- Typography: Bold titles, gray subtitles, clean sans-serif
- Style: Minimal, precise, warm, human-centered

### 6. Quality Settings
- Discovered `image_size="4K"` parameter in Nano Banana API
- Final resolution: **5504×3072 pixels** per slide (vs 1376×768 default)

### 7. Assembly (python-pptx)
```python
from pptx import Presentation
prs = Presentation()
prs.slide_width = Inches(13.333)  # 16:9
for slide_path in slides:
    slide = prs.slides.add_slide(blank_layout)
    slide.shapes.add_picture(str(slide_path), 0, 0, width=prs.slide_width)
prs.save("presentation.pptx")
```

## Key Iterations
1. **Base template**: 4 versions (dense → sparse logos)
2. **Slide layout**: 6 versions (icon size, padding, title position, bullet style)
3. **Mascots**: Regenerated 3 that were cut off at edges
4. **Title slide**: Changed from simple mascot to teacher at chalkboard

## API Flow Summary
```
Claude Code (opus-4-5)     Nano Banana Pro (gemini)
        │                          │
        ├── Crafts prompt ────────►├── Generates base template
        │                          │
        ├── Crafts mascot ────────►├── Generates 12 mascot variations
        │   descriptions           │   (with claude-mascot.png as reference)
        │                          │
        ├── Crafts slide ─────────►├── Generates 12 final slides
        │   prompts                │   (with base + mascot as references)
        │                          │
        └── Assembles .pptx        └── Returns 4K images
```

## Time
~2 hours from idea to final slides

## Commands
```bash
# Generate mascots and slides
python slides/generate.py

# Assemble PowerPoint
python slides/assemble.py
```
