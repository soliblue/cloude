import argparse
import json
import os
from pathlib import Path

from google import genai
from google.genai import types
from PIL import Image
from rembg import remove, new_session

SCRIPT_DIR = Path(__file__).parent
OUTPUT_DIR = SCRIPT_DIR.parent / "output" / "icons"


def generate_icon(prompt: str, client: genai.Client, ref_path: Path = None) -> bytes:
    print(f"Generating: {prompt}...")

    if ref_path:
        parts = [
            types.Part(text=f"Generate an icon in the exact same style as the reference image. The icon should be: {prompt}. Keep the same color palette, line thickness, shading style, and overall aesthetic. Use a plain solid white background."),
            types.Part(inline_data=types.Blob(mime_type="image/png", data=ref_path.read_bytes())),
        ]
    else:
        parts = [types.Part(text=f"Generate a simple, clean icon: {prompt}. Use a minimal style with solid colors, suitable for an app icon. Use a plain solid white background.")]

    response = client.models.generate_content(
        model=os.environ.get("GEMINI_MODEL", "gemini-3-pro-image-preview"),
        contents=[types.Content(parts=parts)],
        config=types.GenerateContentConfig(response_modalities=["image", "text"]),
    )
    for part in response.candidates[0].content.parts:
        if part.inline_data:
            return part.inline_data.data
    raise ValueError("No image in response")


def remove_background(img: Image.Image) -> Image.Image:
    print("Removing background (BiRefNet)...")
    session = new_session("birefnet-general")
    return remove(img, session=session)


def autocrop(img: Image.Image, padding_percent: float = 5.0) -> Image.Image:
    print(f"Autocropping (padding {padding_percent}%)...")
    bbox = img.getbbox()
    if not bbox:
        return img

    cropped = img.crop(bbox)
    obj_width, obj_height = cropped.size

    padding_x = int(obj_width * padding_percent / 100)
    padding_y = int(obj_height * padding_percent / 100)

    result = Image.new("RGBA", (obj_width + 2 * padding_x, obj_height + 2 * padding_y), (0, 0, 0, 0))
    result.paste(cropped, (padding_x, padding_y))
    return result


def save_with_sizes(img: Image.Image, output_dir: Path, name: str, sizes: bool = False) -> Path:
    output_path = output_dir / f"{name}.png"
    img.save(output_path, "PNG")

    if sizes:
        w, h = img.size
        img.resize((w // 2, h // 2), Image.LANCZOS).save(output_dir / f"{name}@2x.png", "PNG")
        img.resize((w // 4, h // 4), Image.LANCZOS).save(output_dir / f"{name}@1x.png", "PNG")
        print(f"Saved: {name}.png (3x), {name}@2x.png, {name}@1x.png")
    else:
        print(f"Saved: {name}.png")

    return output_path


def add_to_assets(output_dir: Path, name: str, assets_dir: Path) -> Path:
    imageset_dir = assets_dir / f"{name}.imageset"
    imageset_dir.mkdir(parents=True, exist_ok=True)

    for suffix, scale in [("@1x", "1x"), ("@2x", "2x"), ("", "3x")]:
        src = output_dir / f"{name}{suffix}.png"
        dst = imageset_dir / f"{name}{suffix}.png"
        dst.write_bytes(src.read_bytes())

    contents = {
        "images": [
            {"filename": f"{name}@1x.png", "idiom": "universal", "scale": "1x"},
            {"filename": f"{name}@2x.png", "idiom": "universal", "scale": "2x"},
            {"filename": f"{name}.png", "idiom": "universal", "scale": "3x"},
        ],
        "info": {"author": "xcode", "version": 1}
    }
    (imageset_dir / "Contents.json").write_text(json.dumps(contents, indent=2))
    print(f"Added to assets: {imageset_dir}")
    return imageset_dir


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--ref", type=Path, help="Reference image for style matching (optional)")
    parser.add_argument("--prompt", required=True, help="Description of the icon to generate")
    parser.add_argument("--output", required=True, help="Output name (without extension)")
    parser.add_argument("--padding", type=float, default=5.0, help="Padding as percentage of object size")
    parser.add_argument("--skip-generate", action="store_true", help="Skip generation, use --input instead")
    parser.add_argument("--input", type=Path, help="Input image (when skipping generation)")
    parser.add_argument("--output-dir", type=Path, default=OUTPUT_DIR, help="Output directory (default: .claude/skills/image/output/icons/)")
    parser.add_argument("--assets-dir", type=Path, help="iOS assets directory to add imageset to")
    parser.add_argument("--sizes", action="store_true", help="Generate 1x, 2x, 3x sizes")
    args = parser.parse_args()

    args.output_dir.mkdir(parents=True, exist_ok=True)

    if args.skip_generate:
        if not args.input:
            raise ValueError("--input required when using --skip-generate")
        img = Image.open(args.input).convert("RGBA")
    else:
        client = genai.Client(api_key=os.environ["GOOGLE_API_KEY"])
        img_bytes = generate_icon(args.prompt, client, args.ref)
        img = Image.open(__import__("io").BytesIO(img_bytes)).convert("RGBA")

    img = remove_background(img)
    img = autocrop(img, args.padding)

    needs_sizes = args.sizes or args.assets_dir
    output_path = save_with_sizes(img, args.output_dir, args.output, needs_sizes)

    if args.assets_dir:
        add_to_assets(args.output_dir, args.output, args.assets_dir)

    print(output_path)
