---
name: slides
description: Create presentation slides using AI image generation. Use for creating slide decks, generating slide images, or iterating on presentation visuals.
user-invocable: true
icon: rectangle.stack.fill
aliases: [presentation, deck, ppt]
---

# Slides Skill

Generate beautiful presentation slides using Nano Banana Pro (Google Gemini image generation).

## Workflow

This is an **iterative, conversational** workflow:

### Phase 1: Planning
1. Discuss the presentation topic with the user
2. Define slide concepts (title, key points, visual idea)
3. Agree on style/branding (colors, mascot, aesthetic)

### Phase 2: Generation (One Slide at a Time)
For each slide:
1. Generate the slide image
2. Show the file path so user can preview on phone
3. Get feedback - regenerate if needed
4. Move to next slide when approved

### Phase 3: Assembly (Optional)
- Combine approved slides into PowerPoint

## Output Directory

All slides go to: `/Users/soli/Desktop/CODING/cloude/.claude/skills/slides/slides/output/`

**File paths are clickable in Cloude** - the user can tap to open and preview each slide image.

## Commands

```bash
# Activate environment
source /Users/soli/Desktop/CODING/cloude/.claude/skills/slides/.venv/bin/activate 2>/dev/null || \
  (cd /Users/soli/Desktop/CODING/cloude/skills/slides && python -m venv .venv && source .venv/bin/activate && pip install -q google-genai pillow python-dotenv python-pptx)

# Load API key
source /Users/soli/Desktop/CODING/cloude/.claude/skills/slides/.env
```

## Generate a Single Slide

Use this Python code pattern (inline in bash):

```bash
source /Users/soli/Desktop/CODING/cloude/.claude/skills/slides/.venv/bin/activate && \
source /Users/soli/Desktop/CODING/cloude/.claude/skills/slides/.env && \
python << 'PYEOF'
import os
from pathlib import Path
from io import BytesIO
from PIL import Image
from google import genai

# Configuration
OUTPUT_DIR = Path("/Users/soli/Desktop/CODING/cloude/.claude/skills/slides/slides/output")
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

client = genai.Client(api_key=os.getenv("GEMINI_API_KEY"))

# Slide parameters - MODIFY THESE
SLIDE_NUMBER = 1
SLIDE_NAME = "title"
SLIDE_PROMPT = """
Create a presentation slide with:
- Title: "Your Title Here"
- Subtitle: "Your subtitle"
- Visual: Description of what should be on the slide
- Style: Clean, professional, minimal

The slide should be suitable for a 16:9 presentation.
Use a clean background. High quality.
"""

# Optional: reference image for style consistency
REFERENCE_PATH = None  # e.g., "/path/to/reference.png"

contents = [SLIDE_PROMPT]
if REFERENCE_PATH and Path(REFERENCE_PATH).exists():
    contents.append(Image.open(REFERENCE_PATH))

response = client.models.generate_content(
    model="models/nano-banana-pro-preview",
    contents=contents,
    config=genai.types.GenerateContentConfig(
        response_modalities=["IMAGE"],
        image_config=genai.types.ImageConfig(
            aspect_ratio="16:9",
        ),
    ),
)

# Save the image
for part in response.candidates[0].content.parts:
    if part.inline_data:
        img = Image.open(BytesIO(part.inline_data.data))
        output_path = OUTPUT_DIR / f"slide_{SLIDE_NUMBER:02d}_{SLIDE_NAME}.png"
        img.save(output_path, "PNG")
        print(f"✓ Generated: {output_path}")
        break
else:
    print("✗ No image generated")
PYEOF
```

## With Reference Image (Style Matching)

To maintain consistent style across slides, use a reference image:

```python
REFERENCE_PATH = "/Users/soli/Desktop/CODING/cloude/.claude/skills/slides/reference/your-style.png"
```

## Assemble into PowerPoint

After all slides are approved:

```bash
source /Users/soli/Desktop/CODING/cloude/.claude/skills/slides/.venv/bin/activate && \
python << 'PYEOF'
from pathlib import Path
from pptx import Presentation
from pptx.util import Inches

OUTPUT_DIR = Path("/Users/soli/Desktop/CODING/cloude/.claude/skills/slides/slides/output")
slides = sorted(OUTPUT_DIR.glob("slide_*.png"))

if not slides:
    print("No slides found!")
    exit(1)

prs = Presentation()
prs.slide_width = Inches(13.333)
prs.slide_height = Inches(7.5)

for slide_path in slides:
    slide = prs.slides.add_slide(prs.slide_layouts[6])  # Blank layout
    slide.shapes.add_picture(
        str(slide_path),
        Inches(0), Inches(0),
        width=prs.slide_width,
        height=prs.slide_height
    )
    print(f"Added: {slide_path.name}")

pptx_path = OUTPUT_DIR / "presentation.pptx"
prs.save(pptx_path)
print(f"\n✓ Saved: {pptx_path}")
PYEOF
```

## Reference Assets

Available in `/Users/soli/Desktop/CODING/cloude/.claude/skills/slides/reference/`:
- `claude-mascot.png` - Orange pixel-art Claude Code character
- `knowunity-background.png` - Branded background template
- `knowunity-logo.png` - Brand logo

## Tips

1. **Iterate one slide at a time** - Generate, preview, refine, approve
2. **Use reference images** - They dramatically improve style consistency
3. **Be specific in prompts** - Describe layout, colors, mood, not just content
4. **File paths are tappable** - User can preview directly on phone via Cloude
5. **Keep slides minimal** - Less text = better AI generation
6. **Model**: `nano-banana-pro-preview` (default, proven in present-claude project)

## Example Session

```
User: I want to make a 5-slide deck about our new feature

Claude: Great! Let's plan:
1. Title slide - feature name + tagline
2. Problem slide - what pain point we solve
3. Solution slide - how we solve it
4. Demo slide - key screenshot/visual
5. CTA slide - next steps

Ready to generate slide 1?

User: Yes

Claude: [generates slide, outputs path]
Generated: /Users/soli/Desktop/CODING/cloude/.claude/skills/slides/slides/output/slide_01_title.png

Take a look and let me know if you want changes.

User: Make the title bigger

Claude: [regenerates with updated prompt]
...
```
