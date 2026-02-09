# Sora Video Generation Skill
<!-- priority: 5 -->

Give Claude the ability to generate videos using OpenAI's Sora, using browser session auth keys from sora.com.

## Background

The `image` skill uses Gemini for image generation. This adds video generation via Sora. Rather than paying for API access ($15-20/min of video), use browser session cookies/auth tokens from sora.com — same approach as unofficial API wrappers.

Sora has an official API (`/v1/videos`) but it requires paid API credits. The web UI at sora.com uses session-based auth that can be extracted from the browser.

## Approach

### 1. Auth extraction
- Extract session token / cookies from browser (Safari or Chrome)
- Store in `.env` or a dedicated config file (gitignored)
- Token refresh strategy — these expire, so either:
  - Manual: user pastes new token when it expires
  - Semi-auto: script to grab from browser cookies DB

### 2. Video generation script
- Standalone script under `tools/sora/` or `skills/video/`
- Hit Sora's internal web API endpoints with session auth
- Support: text-to-video prompt, duration, aspect ratio, style
- Async job — submit, poll for completion, download result
- Output to `skills/video/output/` or similar

### 3. Skill definition
- `/video` skill with aliases: `sora`, `generate video`, `vid`
- Teach Claude when video adds value vs. just an image
- Prompt engineering tips for Sora (what produces good results)
- View output frame / preview after generation

### 4. iOS integration
- Video files render as playable in file preview (already supported?)
- Optionally send video to iOS clipboard or open in player

## Open Questions

- Which browser does Soli use for sora.com? (Safari vs Chrome — different cookie extraction)
- What does the sora.com internal API look like? Need to reverse-engineer endpoints
- Token expiry — how long do session tokens last?
- Does Soli have ChatGPT Plus/Pro? (Sora access requires it)
- Alternative: just use the official API with an OpenAI API key from .env?

## Risk

- Browser session tokens are fragile — OpenAI can change the web API anytime
- Token expiry means manual refresh unless we automate cookie extraction
- If OpenAI locks down the web API, this breaks. Official API is more stable but costs money.
