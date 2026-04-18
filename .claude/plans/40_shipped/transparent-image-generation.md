---
title: "Transparent Image Generation (--transparent flag)"
description: "Added --transparent flag to image generation skill with background removal via rembg and autocrop post-processing."
created_at: 2026-03-03
tags: ["skills"]
icon: photo.artframe
build: 82
---


# Transparent Image Generation (--transparent flag) {photo.artframe}
Added `--transparent` flag to `generate.sh` image skill. Gemini can't output transparent PNGs natively, so the pipeline:

1. Appends "solid white background" to prompt
2. Generates image via Gemini
3. Removes background with rembg (BiRefNet)
4. Autocrops to content bounds + 5% padding
5. Saves as PNG with transparency

Files:
- `.claude/skills/image/generate.sh` — added `--transparent` flag + post-processing
- `.claude/skills/image/SKILL.md` — documented the new option

Also regenerated `claude-scientist.png` with the fixed lab coat using the new flag.
