# Grid Multi-Image Generation

Generate 4 or 9 image variations in a single Gemini API call using a grid template approach.

## Implementation
- `grid.py` — creates grid templates (2x2/3x3) and splits output back into individual images
- `generate.sh` — new `--grid` flag wires up template → Gemini edit → split pipeline
- `SKILL.md` — documented grid mode usage

## Usage
```bash
generate.sh --prompt "cute robots" --grid 2x2 --output robots
# → robots-1.png, robots-2.png, robots-3.png, robots-4.png
```
