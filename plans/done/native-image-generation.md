# Native Image Generation
<!-- priority: 10 -->
<!-- build: 56 -->

Teach Claude to use image models (primarily Nano Banana Pro / Gemini image gen) as a native capability — knowing when and how to generate images without being explicitly told to.

## Background

`icongen` exists for app icons (generation → bg removal → crop → iOS assets). That stays as-is. This is a **separate, general-purpose** image generation skill. Claude should be able to **decide on its own** when an image would be useful and generate one. Examples:
- User describes a UI concept → generate a mockup/reference
- Moltbook post needs a visual → generate an accompanying image
- Slide deck content → generate slide visuals
- Explaining a concept → generate a diagram or illustration
- Any creative task where a picture is worth 1000 tokens

## Skill Definition

- **Name**: `image`
- **Aliases**: `paint`, `draw`, `generate image`, `img`
- **Icon**: `paintbrush.pointed.fill` or similar
- **Separate from `icon`** — no icon pipeline, no bg removal, no iOS asset management. Pure image generation.

### Also: rename `icongen` → `icon`
- Rename skill folder `.claude/skills/icongen/` → `.claude/skills/icon/`
- Update SKILL.md name from `icongen` to `icon`
- Update aliases, script paths accordingly
- Simpler, cleaner naming alongside `image`

## Goals

- Claude can call image generation **without being asked** when it would add value
- Uses Google's image generation (Nano Banana Pro / Gemini) via existing API key
- Skill framework stays intact — this is still a skill, but one Claude reaches for naturally
- Support general use cases: illustrations, mockups, photos, diagrams, art, references
- Claude can view generated images and iterate on them

## Approach

### 1. New generate script
- Standalone script under `skills/image/` — does NOT reuse icongen's pipeline
- Calls Gemini (Nano Banana Pro) directly — Gemini only, no other providers
- No background removal, no autocrop, no iOS asset stuff
- Support aspect ratios, sizes, style prompts
- **Image editing**: pass an existing image + prompt to modify it (Gemini supports this natively, same pattern as icongen's `--ref` but for edits not style matching)
- Output to `skills/image/output/` by default

### 2. Skill definition (SKILL.md)
- Teach Claude WHEN to use it, not just how
- Decision heuristics: "If the user is describing something visual, consider generating an image"
- Prompt engineering tips for Gemini image gen (what works, what doesn't)

### 3. View and iterate
- After generating, read the image file to evaluate quality
- Iterate if needed (re-prompt with adjustments)
- Present the image path to the user so iOS renders it as a file pill

### 4. Model knowledge
- Document which models are available (Nano Banana Pro, Gemini image models)
- What each is good at (photorealism, illustration, text-in-image)
- Prompt style differences between models

## Decisions

- **Gemini only** — no DALL-E, Flux, etc. Keep it simple.
- **Image editing supported** — pass existing image + edit prompt, same as icongen's ref pattern but for modifications
- **Output location**: `skills/image/output/` by default
