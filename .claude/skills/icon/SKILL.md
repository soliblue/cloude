---
name: icon
description: Generate app icons and image assets using AI (Gemini + local background removal). Use when creating icons, generating images for the app, or processing existing images.
user-invocable: true
disable-model-invocation: true
icon: photo.badge.plus
aliases: [icongen, app-icon]
parameters:
  - name: description
    placeholder: Describe the icon...
    required: true
---

# Icon Generation Skill

Generate icons and image assets using the icon pipeline at `.claude/skills/icon`.

## Pipeline

1. **Generate** - Gemini creates the image (with optional style reference)
2. **Remove background** - BiRefNet removes background locally
3. **Autocrop** - Crops to content with padding
4. **Resize** - Creates 1x, 2x, 3x versions for iOS

## Commands

```bash
source .claude/skills/icon/.venv/bin/activate

GOOGLE_API_KEY=$GOOGLE_API_KEY python .claude/skills/icon/generate.py \
  --prompt "description of icon" \
  --output icon_name \
  --assets-dir /Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Assets.xcassets

GOOGLE_API_KEY=$GOOGLE_API_KEY python .claude/skills/icon/generate.py \
  --ref /path/to/reference_icon.png \
  --prompt "description of icon" \
  --output icon_name \
  --assets-dir /Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Assets.xcassets

python .claude/skills/icon/generate.py \
  --skip-generate \
  --input /path/to/image.png \
  --output icon_name \
  --assets-dir /Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Assets.xcassets
```

## Options

- `--prompt` - Description of what to generate
- `--output` - Name for the output file (no extension)
- `--ref` - Reference image for style matching (optional)
- `--input` - Existing image to process (with `--skip-generate`)
- `--padding` - Padding percentage (default 5%)
- `--assets-dir` - iOS assets folder to add imageset to
- `--sizes` - Generate 1x/2x/3x without adding to assets

## Notes

- GOOGLE_API_KEY must be set (available in environment)
- Output goes to `.claude/skills/icon/output/` by default
- With `--assets-dir`, creates proper `.imageset` folder with Contents.json
