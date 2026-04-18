# Image Skill Animation Docs Update {doc.text}
<!-- priority: 10 -->
<!-- tags: skills -->

> Rewrote animation pipeline docs in SKILL.md based on real production experience.

- Full proven pipeline: magenta canvas, Veo 3.1, frame extraction, hybrid bg removal, union bbox crop, GIF assembly
- Hybrid color key approach for pixel art (Apple Vision mask + color key + fringe replacement)
- Background color comparison table (magenta wins)
- ML model comparison table (Vision, rembg, BiRefNet, remove.bg)
- What NOT to do section (per-frame crop jitter, rembg on pixel art, chromakey on compressed frames)
- Updated Veo model to veo-3.1-generate-preview
- Added remove.bg API key reference
