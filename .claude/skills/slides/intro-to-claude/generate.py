import os
from pathlib import Path
from io import BytesIO
from datetime import datetime

from PIL import Image
from dotenv import load_dotenv

load_dotenv()

from google import genai

from prompts import SlidePrompt

BASE_DIR = Path(__file__).parent
OUTPUT_DIR = BASE_DIR / "output"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

FOX_REFERENCES = [
    BASE_DIR.parent / "stickers/output/sticker_20251217_175112.png",
    BASE_DIR.parent / "stickers/output/sticker_20251217_183725.png",
    BASE_DIR.parent / "stickers/output/sticker_20251217_180908.png",
]

SLIDES = [
    {
        "number": 1,
        "title": "Claude Code is NOT just for coders",
        "concept": "Fox looking confused with question marks around its head, sitting at a desk with a laptop showing code. The fox looks skeptical/curious. Clean gradient background.",
    },
    {
        "number": 2,
        "title": "Designers: Generate icons & assets",
        "concept": "Fox wearing a beret and holding a paintbrush, surrounded by colorful floating icons and design elements. Creative artistic vibe with paint splashes.",
    },
    {
        "number": 3,
        "title": "Product: Brainstorm → Tickets",
        "concept": "Fox surrounded by messy sticky notes on one side, and on the other side clean organized Linear/Jira-style ticket cards. Transformation/magic sparkles in the middle.",
    },
    {
        "number": 4,
        "title": "Analytics: Fix queries without being an expert",
        "concept": "Fox wearing glasses looking at SQL code with a confused expression, then a lightbulb appears. Database icons and chart elements in background.",
    },
    {
        "number": 5,
        "title": "Everyone: Automate the boring stuff",
        "concept": "Fox relaxing in a hammock or beach chair while robot arms handle multiple screens showing Slack, emails, spreadsheets. Lazy/satisfied expression.",
    },
    {
        "number": 6,
        "title": "One tool for everything",
        "concept": "Fox as a conductor with a baton, orchestrating floating tool icons (git, Linear, Slack, Metabase, code editor) that orbit around in harmony. Epic/powerful pose.",
    },
    {
        "number": 7,
        "title": "If software is involved → Claude can help",
        "concept": "Fox wearing a superhero cape, confident heroic pose with sparkles and stars around. Inspiring/empowering mood. This is the finale slide.",
    },
]

nanobana_client = genai.Client(api_key=os.getenv("GEMINI_API_KEY"))


def generate_slide(slide: dict, reference_paths: list[Path], model: str = "gemini-3-pro-preview") -> Path:
    print(f"\n{'='*60}")
    print(f"Generating Slide {slide['number']}: {slide['title']}")
    print(f"{'='*60}")

    prompt_result = SlidePrompt(
        model=model,
        reference_image=str(reference_paths[0].resolve()),
        slide_number=slide["number"],
        slide_title=slide["title"],
        slide_concept=slide["concept"],
    )

    print(f"\nGeneration Prompt:\n{prompt_result.generation_prompt}\n")

    print("Generating slide with Nano Banana...")
    reference_images = [Image.open(p) for p in reference_paths]

    response = nanobana_client.models.generate_content(
        model="models/nano-banana-pro-preview",
        contents=[prompt_result.generation_prompt, *reference_images],
        config=genai.types.GenerateContentConfig(
            response_modalities=["IMAGE"],
            image_config=genai.types.ImageConfig(aspect_ratio="16:9"),
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
        output_path = OUTPUT_DIR / f"slide_{slide['number']:02d}.png"
        generated.save(output_path, "PNG")
        print(f"Saved: {output_path}")
        return output_path

    raise ValueError(f"Failed to generate slide {slide['number']}")


def main():
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    run_dir = OUTPUT_DIR / f"run_{timestamp}"
    run_dir.mkdir(parents=True, exist_ok=True)

    print(f"Output directory: {run_dir}")
    print(f"Using {len(FOX_REFERENCES)} reference images")

    generated_slides = []
    for slide in SLIDES:
        output_path = run_dir / f"slide_{slide['number']:02d}.png"

        prompt_result = SlidePrompt(
            model="gemini-3-pro-preview",
            reference_image=str(FOX_REFERENCES[0].resolve()),
            slide_number=slide["number"],
            slide_title=slide["title"],
            slide_concept=slide["concept"],
        )

        print(f"\n{'='*60}")
        print(f"Slide {slide['number']}: {slide['title']}")
        print(f"{'='*60}")
        print(f"Prompt: {prompt_result.generation_prompt[:200]}...")

        reference_images = [Image.open(p) for p in FOX_REFERENCES]

        response = nanobana_client.models.generate_content(
            model="models/nano-banana-pro-preview",
            contents=[prompt_result.generation_prompt, *reference_images],
            config=genai.types.GenerateContentConfig(
                response_modalities=["IMAGE"],
                image_config=genai.types.ImageConfig(aspect_ratio="16:9"),
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
            generated.save(output_path, "PNG")
            print(f"Saved: {output_path}")
            generated_slides.append(output_path)
        else:
            print(f"FAILED to generate slide {slide['number']}")

    print(f"\n{'='*60}")
    print(f"Generated {len(generated_slides)} slides in {run_dir}")
    print(f"{'='*60}")


if __name__ == "__main__":
    main()
