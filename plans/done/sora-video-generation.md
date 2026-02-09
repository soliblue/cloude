# Sora Video Generation Skill
<!-- priority: 5 -->

Give Claude the ability to generate videos using Sora via Soli's ChatGPT Pro subscription ($200/mo, Sora included).

## Status: `/video` skill LIVE

Create → poll → download MP4 is fully functional via Playwright + Webshare US proxy.
Image-guided generation supported via `--image` flag.
Moved from `tools/sora/` to `skills/video/` — now callable as `/video` skill.

## Architecture

### How it works
1. Playwright opens Chrome with a **separate persistent profile** (`skills/video/browser-data/`)
2. Routes through Webshare US proxy (Sora is geo-restricted)
3. Uses saved session cookies to authenticate (no login needed after initial setup)
4. Calls Sora's internal API via `page.evaluate()` (bypasses Cloudflare/Sentinel)
5. Downloads MP4 directly from Azure Blob Storage URLs

### Initial setup (one-time)
```bash
python3 skills/video/session.py login
# Opens Chrome, sign in to sora.chatgpt.com, type 'done'
# Session saved to skills/video/browser-data/
```

### Creating a video
```bash
# Text-only
python3 skills/video/create.py "prompt" -o landscape -s small -f 150

# With reference image
python3 skills/video/create.py "prompt" -o portrait -s small -f 150 --image /path/to/image.png
```

## API Spec (Reverse-Engineered)

### Upload reference image (for image-to-video)
`POST /backend/project_y/file/upload`
- Content-Type: `multipart/form-data`
- Fields: `file` (the image), `use_case` = `"inpaint_safe"`
- Returns: `{ "file_id": "file_...", "asset_pointer": "sediment://file_...", "url": "https://...", "size": 508074, "contains_realistic_person": false }`

### Create video
`POST /backend/nf/create`
```json
{
  "kind": "video",
  "prompt": "...",
  "orientation": "landscape|portrait|square",
  "size": "small|medium|large",
  "n_frames": 150,  // 150=5s, 300=10s, 450=15s, 600=20s
  "inpaint_items": [{"kind": "file", "file_id": "file_..."}],  // empty [] for text-only
  "model": "sy_8",
  // ... other fields null
}
```
Returns: `{ "id": "task_...", "rate_limit_and_credit_balance": { "estimated_num_videos_remaining": 98 } }`

### Poll for completion
`GET /backend/nf/pending/v2`
Returns `[]` when all tasks are done.

### Get download URL
`GET /backend/project_y/profile/drafts?limit=5`
Returns drafts with:
- `download_urls.no_watermark` — direct Azure Blob URL for MP4
- `download_urls.watermark` — watermarked version
- `downloadable_url` — same as no_watermark
- `width`, `height`, `duration_s`, `prompt`

### Other useful endpoints
- `GET /backend/nf/check` — check account status
- `GET /backend/project_y/profile_feed/me?limit=8&cut=nf2` — published videos
- `GET /backend/project_y/download/{post_id}` — download published video

### Available models
- `sy_ore` — Sora 2 Pro
- `sy_8` — Sora 2 (default)
- `sy_8_20251208` — Sora 2 2025-12-08

## Auth Details

- Session persists in `skills/video/browser-data/` (gitignored)
- `__Secure-next-auth.session-token` cookie is the long-lived session (~3 months)
- Access token (JWT) refreshed automatically via `/api/auth/session` (~10 day lifetime)
- Webshare API key in `.env` — auto-fetches US proxy

## Files

- `skills/video/create.py` — full create → poll → download flow (supports `--image`)
- `skills/video/session.py` — login (initial setup) and create modes
- `skills/video/login.py` — initial auth via personal Chrome profile
- `skills/video/explore.py` — debug tool, opens browser with request logging
- `skills/video/test_flow.py` — inspect pending/drafts/feed data
- `skills/video/capture_share.py` — capture draft metadata and download URLs
- `skills/video/capture_image_flow.py` — reverse-engineer image upload API
- `skills/video/browser-data/` — persistent browser session (gitignored)
- `skills/video/output/` — downloaded MP4s (gitignored)
- `.claude/skills/video/SKILL.md` — skill definition

### Debugging image-to-video (for future API capture)
If the image upload API changes, use `capture_image_flow.py` to reverse-engineer it again:
```bash
python3 skills/video/capture_image_flow.py
# Opens browser, logs all /backend/ requests with full bodies
# Attach image + generate in Sora UI, type 'done'
# Output saved to image_flow_capture.json
```

## Remaining Work

### Done
- [x] Create `/video` skill in `.claude/skills/`
- [x] SKILL.md with usage instructions, prompt tips
- [x] Make it callable from Claude conversations
- [x] Move all files from `tools/sora/` → `skills/video/`

### Future: Token refresh automation
- [ ] Playwright script to auto-refresh session when it expires
- [ ] Currently manual: re-run `session.py login` when session dies

### Future: Headless mode
- [ ] Switch to headless once everything is stable
- [ ] Keep non-headless as debug/fallback option
