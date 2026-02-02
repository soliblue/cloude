# icongen

Reusable icon generation pipeline: generate → remove background → autocrop → 1x/2x/3x sizing.

Location: `/Users/soli/Desktop/CODING/cloude/skills/icongen/`

## Setup

```bash
cd /Users/soli/Desktop/CODING/cloude/skills/icongen
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

## Usage

```bash
cd /Users/soli/Desktop/CODING/cloude/skills/icongen
source .venv/bin/activate

# Generate with Cloude pixel art style (use ref-creature.png)
source .env && GOOGLE_API_KEY=$GOOGLE_API_KEY python generate.py \
  --ref ref-creature.png \
  --prompt "description of icon" \
  --output cloude-name

# Generate without reference
source .env && GOOGLE_API_KEY=$GOOGLE_API_KEY python generate.py \
  --prompt "a simple heart icon" \
  --output icon-heart

# Process existing image (skip generation)
python generate.py \
  --skip-generate \
  --input ~/Downloads/my_icon.png \
  --output icon-processed

# Add directly to iOS assets folder
python generate.py \
  --prompt "heart icon" \
  --output icon-heart \
  --assets-dir /Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Assets.xcassets

# Generate 1x, 2x, 3x sizes
python generate.py --prompt "heart icon" --output icon-heart --sizes

# Custom padding (default 5%)
python generate.py ... --padding 10
```

## Output

Default output in `output/`:
- `{name}.png` - high quality original

With `--sizes` flag, also generates:
- `{name}@2x.png` - 2x (half size)
- `{name}@1x.png` - 1x (quarter size)

With `--assets-dir` (implies `--sizes`), also creates:
- `{assets-dir}/{name}.imageset/` with all sizes + Contents.json

## Agent Integration

```bash
# Generate with Cloude style and add to iOS assets
source /Users/soli/Desktop/CODING/cloude/skills/icongen/.venv/bin/activate && \
  source /Users/soli/Desktop/CODING/cloude/.env && \
  GOOGLE_API_KEY=$GOOGLE_API_KEY python /Users/soli/Desktop/CODING/cloude/skills/icongen/generate.py \
  --ref /Users/soli/Desktop/CODING/cloude/skills/icongen/ref-creature.png \
  --prompt "description" \
  --output cloude-name \
  --assets-dir /Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Assets.xcassets
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

## Asset Naming Conventions

Follow these naming patterns for all generated assets:

### Prefixes by Category

| Prefix | Use Case | Example |
|--------|----------|---------|
| `cloude-` | Main Cloude character/mascot | `cloude-idle.png`, `cloude-thinking.png` |
| `icon-` | UI icons (buttons, tabs, actions) | `icon-send.png`, `icon-settings.png` |
| `avatar-` | User/profile images | `avatar-user.png`, `avatar-guest.png` |
| `state-` | App states/status indicators | `state-offline.png`, `state-error.png` |
| `bg-` | Backgrounds/decorative | `bg-clouds.png`, `bg-gradient.png` |

### Naming Rules

- **Lowercase with hyphens**: `cloude-happy.png` not `Cloude_Happy.png`
- **Descriptive but concise**: `icon-send.png` not `icon-send-message-button.png`
- **No version numbers in names**: Use archive folder for old versions
- **Variants use suffixes**: `cloude-idle-dark.png`, `icon-send-filled.png`

### Output Structure

```
output/
├── cloude-*.png      # Character assets
├── icon-*.png        # UI icons
├── avatar-*.png      # Profile images
├── state-*.png       # Status indicators
└── archive/          # Unused/old versions
```

### Reference Files (root folder)

Keep reference images in the skill root (not output):
- `ref-creature.png` - Main Cloude pixel art reference (use for all Cloude-style generation)
