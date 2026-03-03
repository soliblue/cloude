# Sora Marketing Experiments

> Daily video generation experiments using 100 free Sora credits. Goal: build a library of marketing assets for Twitter, explore what works, push Sora's limits, learn fast.

## Strategy

**Volume over perfection.** Generate ~50-100 videos per day across different directions. Each batch teaches something. Track what looks good and double down.

## Experiment Directions

### 1. App Screenshots → Animated
- Take real screenshots of Cloude (via `cloude screenshot`)
- Feed to Sora with image-to-video to animate the UI
- Motion prompts: "subtle parallax", "messages appearing", "gentle glow"
- Goal: show the real app in motion, cinematic feel

### 2. Pixel Characters in the Clouds
- Use existing character PNGs (baby, chef, cowboy, wizard, ninja, artist, grandpa)
- Generate mood board compositions with Gemini first
- Feed to Sora: characters floating, flying, interacting in cloud worlds
- Goal: brand identity, fun shareable content

### 3. Concept Videos
- "Your phone is your laptop" — phone morphing into a dev setup
- "AI that remembers you" — visual metaphor for persistent memory
- "Deploy from your couch" — cozy + powerful contrast
- Goal: communicate the product vision cinematically

### 4. Abstract / Vibes
- Claude orange/terracotta palette, clouds, ethereal
- Typography + motion graphics feel
- Goal: pinned tweet / profile header energy

### 5. Screen Recordings + Sora Hybrid
- Real app footage intercut with Sora-generated transitions
- Goal: best of both worlds — authentic + cinematic

## Learnings Log

Track what works after each batch:
- (empty — start generating!)

## Assets

- Character PNGs: `Cloude/Cloude/Assets.xcassets/*-claude.imageset/`
- Video output: `skills/video/output/`
- Image output: `skills/image/output/`
- Sora skill: `.claude/skills/video/SKILL.md`
