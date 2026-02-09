# Sora Video Generation Skill
<!-- priority: 5 -->

Give Claude the ability to generate videos using Sora via Soli's ChatGPT Pro subscription ($200/mo, Sora included).

## Status: Core flow WORKING

Create → poll → download MP4 is fully functional via Playwright + Webshare US proxy.

## Architecture

### How it works
1. Playwright opens headless Chrome with a **separate persistent profile** (`tools/sora/browser-data/`)
2. Routes through Webshare US proxy (Sora is geo-restricted)
3. Uses saved session cookies to authenticate (no login needed after initial setup)
4. Calls Sora's internal API via `page.evaluate()` (bypasses Cloudflare/Sentinel)
5. Downloads MP4 directly from Azure Blob Storage URLs

### Initial setup (one-time)
```bash
python3 tools/sora/session.py login
# Opens Chrome, sign in to sora.chatgpt.com, type 'done'
# Session saved to tools/sora/browser-data/
```

### Creating a video
```bash
python3 tools/sora/create.py "prompt" [orientation] [size] [n_frames]
```

## API Spec (Reverse-Engineered)

### Create video
`POST /backend/nf/create`
```json
{
  "kind": "video",
  "prompt": "...",
  "orientation": "landscape|portrait|square",
  "size": "small|medium|large",
  "n_frames": 150,  // 150=5s, 300=10s, 450=15s, 600=20s
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

## Auth Details

- Session persists in `tools/sora/browser-data/` (gitignored)
- `__Secure-next-auth.session-token` cookie is the long-lived session (~3 months)
- Access token (JWT) refreshed automatically via `/api/auth/session` (~10 day lifetime)
- Webshare API key in `.env` — auto-fetches US proxy

## Files

- `tools/sora/session.py` — login (initial setup) and create modes
- `tools/sora/create.py` — full create → poll → download flow
- `tools/sora/explore.py` — debug tool, opens browser with request logging
- `tools/sora/test_flow.py` — inspect pending/drafts/feed data
- `tools/sora/browser-data/` — persistent browser session (gitignored)
- `tools/sora/output/` — downloaded MP4s (gitignored)

## Remaining Work

### Next: Skill definition
- [ ] Create `/video` skill in `.claude/skills/`
- [ ] SKILL.md with usage instructions, prompt tips
- [ ] Make it callable from Claude conversations

### Next: iOS integration
- [ ] Verify .mp4 files render playable in file preview
- [ ] If not, add AVPlayer support to FilePreviewView

### Future: Image-to-video
- [ ] Capture API format for image attachments (need manual test)
- [ ] `remix_target_id`, `inpaint_items`, `storyboard_id` fields

### Future: Token refresh automation
- [ ] Playwright script to auto-refresh session when it expires
- [ ] Currently manual: re-run `session.py login` when session dies

### Future: Headless mode
- [ ] Switch to headless once everything is stable
- [ ] Keep non-headless as debug/fallback option
