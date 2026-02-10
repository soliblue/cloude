import os
from pathlib import Path
from io import BytesIO
from datetime import datetime

from PIL import Image
from dotenv import load_dotenv

load_dotenv()

from google import genai

BASE_DIR = Path(__file__).parent
REFERENCE_DIR = BASE_DIR.parent / "reference"
OUTPUT_DIR = BASE_DIR / "output"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

# Claude Code mascot reference
CLAUDE_MASCOT = REFERENCE_DIR / "claude-mascot.png"

# Mascot variations for each slide concept
MASCOT_VARIATIONS = [
    {
        "number": 1,
        "name": "title_collaborative",
        "concept": "The Claude Code mascot (orange pixel character) standing proudly, professional pose. Could be wearing a tiny tie or looking polished. Friendly and welcoming. Clean background, suitable for a title slide.",
    },
    {
        "number": 2,
        "name": "multi_agent_conductor",
        "concept": "The Claude Code mascot as an orchestra conductor, holding a baton, conducting multiple smaller versions of itself. Each mini-Claude has a different accessory (headphones, glasses, hard hat) representing different roles. Organized chaos, teamwork vibe.",
    },
    {
        "number": 3,
        "name": "graduation",
        "concept": "The Claude Code mascot wearing a graduation cap, holding a diploma. Walking from a messy 'playground' area toward a clean 'production' area. Proud achievement moment. Code graduating to production.",
    },
    {
        "number": 4,
        "name": "memory_brain",
        "concept": "The Claude Code mascot with a glowing brain or memory visualization above its head. Holding a file labeled 'CLAUDE.md'. Knowledge flowing into the brain and staying there. Wise, knowledgeable expression.",
    },
    {
        "number": 5,
        "name": "general_army",
        "concept": "The Claude Code mascot as a military general with a hat/medals, standing in front of an organized army of identical Claude mascots in formation. Each soldier-Claude in their own lane/row. Coordinated, disciplined, but still cute.",
    },
    {
        "number": 6,
        "name": "scientist_notes",
        "concept": "The Claude Code mascot as a scientist in a lab coat, holding a clipboard with notes. Surrounded by beakers, test tubes, and a whiteboard with 'v1, v2, v3' written on it. Experimenting and documenting. Lab/research aesthetic.",
    },
    {
        "number": 7,
        "name": "judge_loop",
        "concept": "The Claude Code mascot split into two: one generating/creating, one as a judge with a gavel giving thumbs up/down. Circular arrows between them showing iteration. Quality control loop visualization.",
    },
    {
        "number": 8,
        "name": "inception_mirror",
        "concept": "The Claude Code mascot looking into a mirror, but the reflection is also a Claude mascot that's configuring/adjusting the original. Meta, recursive, inception-like. Maybe the reflection is holding tools/wrench. Mind-bending but playful.",
    },
    {
        "number": 9,
        "name": "helpful_assistant",
        "concept": "The Claude Code mascot as a friendly office assistant, helping tiny human figures (non-technical looking - could have calculator, spreadsheet icons). Bridging tech and non-tech. Approachable helper vibe.",
    },
    {
        "number": 10,
        "name": "builder_maker",
        "concept": "The Claude Code mascot as a maker/builder, surrounded by tools it created: a phone, a Slack logo, a microphone. Workshop/garage aesthetic. Proud creator showing off inventions. DIY empowerment.",
    },
    {
        "number": 11,
        "name": "habibi_relaxed",
        "concept": "The Claude Code mascot lounging on a couch or beach chair, casually holding a phone. In the background, a conveyor belt shows: code → rocket → app store icon. Relaxed but productive. 'Shipping from anywhere' vibe. Maybe wearing sunglasses.",
    },
    {
        "number": 12,
        "name": "questions_open",
        "concept": "The Claude Code mascot with open arms, welcoming pose. Question marks floating around playfully. Friendly, approachable, ready to help. 'Ask me anything' energy.",
    },
]

STYLE_PROMPT = """
Generate an illustration of the Claude Code mascot character.

REFERENCE CHARACTER:
- The reference image shows the Claude Code mascot - a cute, simple, pixel-art style orange/terracotta colored character
- It has a blocky/pixelated aesthetic, simple face, stubby legs
- Keep this exact character design but put it in new scenarios/poses

STYLE REQUIREMENTS:
- Maintain the pixel-art, blocky, cute aesthetic of the original mascot
- Clean illustration on a simple or transparent-friendly background
- The character should be the main focus, centered
- High quality, crisp edges
- Suitable for placing on presentation slides
- NO text in the image
- Background should be simple (solid color, subtle gradient, or minimal environment)

IMPORTANT:
- This is the Claude Code mascot - keep its distinctive look
- Don't make it too realistic - keep the cute pixel art style
- The mascot can wear accessories or be in scenarios but should remain recognizable
"""

nanobana_client = genai.Client(api_key=os.getenv("GEMINI_API_KEY"))


def generate_mascot(variation: dict, reference_image: Image.Image, output_dir: Path) -> Path:
    print(f"\n{'='*60}")
    print(f"Generating: {variation['name']}")
    print(f"{'='*60}")

    prompt = f"""{STYLE_PROMPT}

VARIATION #{variation['number']}: {variation['name']}
Concept: {variation['concept']}

Generate this mascot variation now. Keep the Claude Code character recognizable while adapting it to this concept.
"""

    print(f"Concept: {variation['concept'][:100]}...")

    response = nanobana_client.models.generate_content(
        model="models/nano-banana-pro-preview",
        contents=[prompt, reference_image],
        config=genai.types.GenerateContentConfig(
            response_modalities=["IMAGE"],
            image_config=genai.types.ImageConfig(aspect_ratio="1:1"),
        ),
    )

    generated = next(
        (
            Image.open(BytesIO(part.inline_data.data))
            for part in (response.candidates[0].content.parts if response.candidates and response.candidates[0].content else [])
            if part.inline_data
        ),
        None,
    )

    if generated:
        output_path = output_dir / f"{variation['number']:02d}_{variation['name']}.png"
        generated.save(output_path, "PNG")
        print(f"Saved: {output_path}")
        return output_path

    raise ValueError(f"Failed to generate: {variation['name']}")


def main():
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    run_dir = OUTPUT_DIR / f"run_{timestamp}"
    run_dir.mkdir(parents=True, exist_ok=True)

    print(f"Output directory: {run_dir}")
    print(f"Loading Claude Code mascot reference...")

    if not CLAUDE_MASCOT.exists():
        raise FileNotFoundError(f"Claude mascot not found at {CLAUDE_MASCOT}")

    reference_image = Image.open(CLAUDE_MASCOT)
    print(f"Loaded reference: {CLAUDE_MASCOT}")

    generated = []
    for variation in MASCOT_VARIATIONS:
        try:
            output_path = generate_mascot(variation, reference_image, run_dir)
            generated.append(output_path)
        except Exception as e:
            print(f"Error generating {variation['name']}: {e}")

    print(f"\n{'='*60}")
    print(f"Generated {len(generated)}/{len(MASCOT_VARIATIONS)} mascot variations")
    print(f"Output: {run_dir}")
    print(f"{'='*60}")


if __name__ == "__main__":
    main()
