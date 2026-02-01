# icongen

Reusable icon generation pipeline: generate → remove background → autocrop → 1x/2x/3x sizing.

## Setup

```bash
cd /Users/soli/Desktop/CODING/icongen
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

## Usage

```bash
cd /Users/soli/Desktop/CODING/icongen
source .venv/bin/activate

# Generate with reference style
GOOGLE_API_KEY=your_key python generate.py \
  --ref ~/path/to/reference_icon.png \
  --prompt "a simple heart icon" \
  --output icon_heart

# Generate without reference (uses default minimal style)
GOOGLE_API_KEY=your_key python generate.py \
  --prompt "a simple heart icon" \
  --output icon_heart

# Process existing image (skip generation)
python generate.py \
  --skip-generate \
  --input ~/Downloads/my_icon.png \
  --output icon_processed

# Add directly to iOS assets folder
python generate.py \
  --prompt "heart icon" \
  --output icon_heart \
  --assets-dir ~/Projects/MyApp/Assets.xcassets/Icons

# Generate 1x, 2x, 3x sizes
python generate.py --prompt "heart icon" --output icon_heart --sizes

# Custom padding (default 5%)
python generate.py ... --padding 10
```

## Output

Default output in `icongen/output/`:
- `{name}.png` - high quality original

With `--sizes` flag, also generates:
- `{name}@2x.png` - 2x (half size)
- `{name}@1x.png` - 1x (quarter size)

With `--assets-dir` (implies `--sizes`), also creates:
- `{assets-dir}/{name}.imageset/` with all sizes + Contents.json

## Agent Integration

```bash
# Generate and get output path
OUTPUT=$(source /Users/soli/Desktop/CODING/icongen/.venv/bin/activate && \
  GOOGLE_API_KEY=$GOOGLE_API_KEY python /Users/soli/Desktop/CODING/icongen/generate.py \
  --prompt "heart icon" \
  --output icon_heart)

# Generate and add to iOS project assets
source /Users/soli/Desktop/CODING/icongen/.venv/bin/activate && \
  GOOGLE_API_KEY=$GOOGLE_API_KEY python /Users/soli/Desktop/CODING/icongen/generate.py \
  --prompt "heart icon" \
  --output icon_heart \
  --assets-dir /path/to/App/Assets.xcassets/Icons
```

## Pipeline Steps

1. **Generate** - Uses Gemini (matches reference style if provided, otherwise minimal style)
2. **Remove background** - Uses BiRefNet (local, no API calls)
3. **Autocrop** - Crops to content bounds + adds padding
4. **Resize** - Creates 1x, 2x, 3x versions
5. **Add to assets** - (optional) Creates iOS imageset with Contents.json

## Environment Variables

- `GOOGLE_API_KEY` - Required for generation step
- `GEMINI_MODEL` - Optional, defaults to `gemini-2.0-flash-exp`
