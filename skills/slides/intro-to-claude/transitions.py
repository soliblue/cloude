import os
import time
import argparse
import requests
from pathlib import Path

from dotenv import load_dotenv

load_dotenv()

import replicate

BASE_DIR = Path(__file__).parent
OUTPUT_DIR = BASE_DIR / "output"

TRANSITION_PROMPTS = [
    "The fox's confused expression transforms into artistic inspiration, question marks morph into colorful paint splashes",
    "Messy sticky notes magically organize themselves into neat ticket cards, the fox waves a wand",
    "The artistic fox puts on glasses, paint brushes transform into database charts and SQL code",
    "The fox closes the laptop, stretches, and robot arms emerge to handle the screens while fox relaxes",
    "The fox stands up confidently, tools begin orbiting around like planets, fox raises conductor baton",
    "The fox's cape billows heroically, sparkles intensify, triumphant superhero landing pose",
]


def generate_transition(start_image_path: Path, prompt: str, output_path: Path, duration: int = 5) -> Path:
    print(f"Generating transition: {prompt[:50]}...")

    with open(start_image_path, "rb") as f:
        output = replicate.run(
            "kwaivgi/kling-v2.6",
            input={
                "prompt": prompt,
                "start_image": f,
                "duration": duration,
                "aspect_ratio": "16:9",
                "generate_audio": False,
            },
        )

    if output:
        video_url = output if isinstance(output, str) else str(output)
        print(f"Downloading from: {video_url}")

        response = requests.get(video_url)
        response.raise_for_status()

        output_path.write_bytes(response.content)
        print(f"Saved: {output_path}")
        return output_path

    raise ValueError("Failed to generate transition")


def main():
    parser = argparse.ArgumentParser(description="Generate video transitions between slides using Kling")
    parser.add_argument("--slides-dir", type=str, required=True, help="Directory containing slide images")
    parser.add_argument("--duration", type=int, default=5, help="Transition duration in seconds (5 or 10)")
    args = parser.parse_args()

    slides_dir = Path(args.slides_dir)
    transitions_dir = slides_dir / "transitions"
    transitions_dir.mkdir(parents=True, exist_ok=True)

    slide_files = sorted(slides_dir.glob("slide_*.png"))
    print(f"Found {len(slide_files)} slides")

    if len(slide_files) < 2:
        print("Need at least 2 slides to create transitions")
        return

    for i in range(len(slide_files) - 1):
        start_slide = slide_files[i]
        prompt = TRANSITION_PROMPTS[i] if i < len(TRANSITION_PROMPTS) else "Smooth cinematic transition to the next scene"

        output_path = transitions_dir / f"transition_{i+1:02d}_to_{i+2:02d}.mp4"

        if output_path.exists():
            print(f"Skipping existing: {output_path}")
            continue

        print(f"\n{'='*60}")
        print(f"Transition {i+1} → {i+2}")
        print(f"{'='*60}")

        generate_transition(start_slide, prompt, output_path, args.duration)
        time.sleep(2)

    print(f"\n{'='*60}")
    print(f"Generated transitions in {transitions_dir}")
    print(f"{'='*60}")


if __name__ == "__main__":
    main()
