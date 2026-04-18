---
title: "Image Skill Animation Docs Update"
description: "Rewrote animation pipeline docs in SKILL.md based on real production experience."
created_at: 2026-03-15
tags: ["skills"]
icon: doc.text
build: 86
---


# Image Skill Animation Docs Update {doc.text}
- Full proven pipeline: magenta canvas, Veo 3.1, frame extraction, hybrid bg removal, union bbox crop, GIF assembly
- Hybrid color key approach for pixel art (Apple Vision mask + color key + fringe replacement)
- Background color comparison table (magenta wins)
- ML model comparison table (Vision, rembg, BiRefNet, remove.bg)
- What NOT to do section (per-frame crop jitter, rembg on pixel art, chromakey on compressed frames)
- Updated Veo model to veo-3.1-generate-preview
- Added remove.bg API key reference
