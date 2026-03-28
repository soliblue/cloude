# Animated Empty State - Painter {paintbrush.fill}
<!-- priority: 5 -->
<!-- tags: ui -->

> Animate the painter empty-state character so the chat start screen feels more alive.

Animate the painter pixel Claude for the empty chat state, same as we did for boxer.

## Progress So Far

### Pipeline Tested
1. Put character on solid color background (16:9 = 1280x720 to match Veo output)
2. Send to Veo 3.0 (`veo-3.0-generate-001`) for 4s video generation
3. Extract frames with ffmpeg
4. Remove background per frame
5. Assemble GIF + optimize with `gifsicle -O3 --lossy=30 --colors 128`

### Background Colors Tested
- **Green (#00FF00)**: ffmpeg chromakey works but leaves green fringe on orange edges
- **White (#FFFFFF)**: remove.bg API gives perfect results, rembg decent
- **Magenta (#FF00FF)**: Best for chromakey since zero color overlap with orange characters. 853KB final GIF, cleanest edges without API

### Background Removal Approaches Compared
| Approach | Background | Quality | Size | Notes |
|----------|-----------|---------|------|-------|
| ffmpeg chromakey | green | Good, slight fringe | 1.4MB | Instant, free |
| ffmpeg chromakey | magenta | Great, no fringe | 853KB | Best free option |
| rembg default | green | Good | 2.1MB | 0.8s/frame |
| rembg default | white | Good | 1.4MB | 0.8s/frame |
| rembg BiRefNet | green | Slightly better | 469KB (48 frames) | 16s/frame, too slow |
| remove.bg API | white | Perfect | 44KB (9 frames) | Best quality but costs credits |

### Winner So Far
**Magenta background + ffmpeg chromakey** is the best free approach. If we get more remove.bg credits, **white background + remove.bg API** is the absolute best quality.

### Test Files on Desktop
- `painter-loop-magenta.gif` - magenta chromakey (853KB, 96 frames) - best free
- `painter-loop-rembg-white.gif` - rembg on white (1.4MB, 96 frames)
- `painter-loop.gif` - ffmpeg chromakey on green (1.4MB, 192 frames)
- `painter-loop-rembg.gif` - rembg on green (2.1MB, 192 frames)
- `painter-loop-v31.mp4` - Veo 3.1 raw video (not GIF'd)

### Still TODO
- [ ] Pick final approach (magenta chromakey vs wait for remove.bg credits)
- [ ] Fix GIF sizing issue in app (AnimatedGIFView not respecting SwiftUI frame)
- [ ] Add painter GIF to `Cloude/Cloude/Resources/claude-painter-anim.gif`
- [ ] Add "claude-painter" to `animatedCharacters` set in `ConversationView+EmptyState.swift`
- [ ] Consider gitignoring `*.gif` in Resources/
- [ ] Do builder and explorer next

### Key Learnings
- Input image MUST match Veo's output aspect ratio (16:9 or 9:16) to avoid black bars
- Veo only supports 16:9 and 9:16, no 1:1
- `duration_seconds=4` is minimum, saves API cost during iteration
- remove.bg API keys are in habibi/.env (`REMOVEBG_API_KEY` and `REMOVEBG_API_KEY_ALT`)
- Both keys are at 0 credits as of 2026-03-14
- Image skill updated with full animation pipeline docs
