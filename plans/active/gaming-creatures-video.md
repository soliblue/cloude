# Gaming Creatures Video — Full Recipe

The third compilation video (`03-gaming-creatures.mp4`) came out incredible. This documents the exact pipeline so we can reproduce and extend it.

## Result

`/Users/soli/Desktop/CODING/cloude/.claude/skills/video/output/compilations/03-gaming-creatures.mp4`

4 clips stitched together (~20 seconds): Space Invaders → Platformer → Fighter → Kart Racing. (Pac-Man creatures clip missing — Sora download URL issue, still in drafts.)

## Pipeline

### Step 1: Character Roster

Generated 10 pixel art character variants from `ref-creature.png` using Gemini image editing. Each prompt sends the ref creature and asks for a themed version on white background.

**Reference image:** `/Users/soli/Desktop/CODING/cloude/.claude/skills/icon/ref-creature.png`

**Prompt template:**
```
Same exact pixel art character as the reference image — same orange/brown square head, same black dot eyes, same stick legs, same proportions. But now dressed as a [ROLE]: [ACCESSORIES]. Full body visible, character small and centered with lots of white space around it. White background. Same pixel art style as reference.
```

**Characters generated:** DJ, Hacker, Astronaut, Samurai, Scientist, Boxer, Skater, King, Rockstar, Pirate

**Background removal:** BiRefNet (`rembg` with `birefnet-general` session) on all 10, then autocrop with 5% padding. Saved as transparent PNGs.

**Roster composite:** All 10 characters combined into `roster-all.png` (5x2 grid, white background).

### Step 2: Mood Board

Sent the roster composite to Gemini with a director's mood board prompt.

**Reference image:** `/Users/soli/Desktop/CODING/cloude/.claude/skills/video/assets/characters/roster-all.png`

**Gemini prompt:**
```
Director's mood board for CLOUDE GAMING — retro video games featuring these pixel art characters. Layout: vertical mood board with 6 panels showing different game scenes. Include: (1) Pac-Man style maze game — one character chasing others through a neon pixel maze, eating power pellets, (2) Street Fighter style fighting game — two characters facing off with health bars and pixel effects, (3) Mario-style platformer — character jumping across cloud platforms collecting coins, (4) Space Invaders style — characters as ships shooting pixel bullets at waves of enemies, (5) Racing game — characters in tiny pixel karts racing on a rainbow road through clouds, (6) Game selection screen — a pixel art Nintendo-style console/tablet showing game thumbnails. Style: 16-bit retro game aesthetic, scanlines, bright saturated colors, arcade feel. Each panel labeled with game type. Dark background between panels.
```

**Aspect ratio:** 9:16 (vertical)
**Output:** `/Users/soli/Desktop/CODING/cloude/.claude/skills/video/assets/moodboard-gaming-creatures.jpg`

### Step 3: First Frames (Gemini)

For each video, generated a single scene frame by sending the mood board as `--edit` reference with a detailed scene prompt. Key: "Single scene, full frame, no panels" to avoid Gemini making another mood board.

**Reference image for all:** The mood board from Step 2.

#### Frame 11 — Pac-Man Creatures
```
Single scene, full frame, no panels: Pac-Man style arcade game screen. A dark blue maze with pixel walls and glowing dots. The pirate creature (orange square head, pirate hat, eyepatch) is the Pac-Man character with mouth wide open, chasing three ghost-like creatures (the astronaut, boxer, and skater) through the maze. Power pellets in corners, score counter at top showing SCORE 1250. Classic arcade aesthetic with dark background and neon maze walls. 16-bit retro game style. Landscape orientation. First frame of animated video.
```

#### Frame 12 — Fighter Game
```
Single scene, full frame, no panels: Street Fighter style pixel art fighting game. The boxer creature (orange square head, red boxing gloves, red headband, sweat drops) on the left VS the samurai creature (red headband, armor, katana) on the right. Both in fighting stances. Health bars at the top, city backdrop with buildings. KO and HIT pixel text effects flying. Classic 2D fighting game UI with character names below health bars. 16-bit retro fighting game style, dramatic action pose. Landscape orientation. First frame of animated video.
```

#### Frame 13 — Platformer
```
Single scene, full frame, no panels: Mario-style platformer game. The astronaut creature (orange square head, white space helmet and suit) jumping mid-air between cloud platforms. Gold coins floating in the air, cloud platform blocks, question mark blocks, a flag pole in the distance. Blue sky background with fluffy clouds. Score and lives counter at top. Classic side-scrolling platformer layout. 16-bit retro game pixel art, bright cheerful colors. Landscape orientation. First frame of animated video.
```

#### Frame 14 — Space Invaders
```
Single scene, full frame, no panels: Space Invaders style shooter. Dark space background with stars. Rows of alien invaders at the top — but they're pixel creatures wearing different hats (pirate hats, wizard hats, crowns). At the bottom, the hacker creature in a tiny spaceship shooting pixel lasers upward. Explosions and pixel debris. Shield barriers in the middle. Score at top, lives remaining. Classic Space Invaders layout. 16-bit retro arcade pixel art, dark with neon. Landscape orientation. First frame of animated video.
```

#### Frame 15 — Kart Racing
```
Single scene, full frame, no panels: Rainbow Road kart racing game. The king creature in a gold kart, the rockstar creature in a red kart, the skater creature in a blue kart, and the DJ creature in a purple kart — all racing on a glowing rainbow road that winds through clouds. Items and power-ups floating above the track. Position indicators (1st, 2nd, 3rd). Speed lines and sparkle effects. The track curves dramatically against a twilight sky. 16-bit retro racing game pixel art, vibrant rainbow colors. Landscape orientation. First frame of animated video.
```

**Aspect ratio:** 16:9 (landscape)
**Output:** `/Users/soli/Desktop/CODING/cloude/.claude/skills/video/assets/frames/frame-11-*.jpg` through `frame-15-*.jpg`

### Step 4: Sora Video Generation (Image-to-Video)

Each frame was sent to Sora as image-to-video. Prompts describe ONLY ambient motion — no camera movement, no character locomotion (those break image-to-video).

**Batch JSON:** `/Users/soli/Desktop/CODING/cloude/.claude/skills/video/experiments/batch18-gaming-creatures.json`

| Frame | Sora Prompt | Output |
|-------|-------------|--------|
| Space Invaders | "Subtle ambient motion: stars twinkle in space, laser beams flash, explosions flicker, alien rows shift slightly, shield barriers pulse. No new objects, preserve exact art style." | `sora_762119367.mp4` |
| Platformer | "Subtle ambient motion: coins spin and glitter, clouds drift in background, question blocks pulse, character cape flutters in wind. No new objects, preserve exact art style." | `sora_762121453.mp4` |
| Fighter | "Subtle ambient motion: hit effects flash, health bars pulse, pixel dust particles drift, background buildings shimmer with heat haze. No new objects, preserve exact art style." | `sora_762123577.mp4` |
| Kart Racing | "Subtle ambient motion: rainbow road glows and shimmers, speed lines streak, sparkle effects flash, exhaust trails from karts, items spin above track. No new objects, preserve exact art style." | `sora_762131632.mp4` |
| Pac-Man | "Subtle ambient motion: neon maze walls pulse and glow, dots flicker, ghost characters drift slightly, score counter flashes. No new objects, preserve exact art style." | ❌ Download failed |

**Settings:** landscape, 150 frames (5s), small size (640x352 actual)

### Step 5: Stitching

```bash
ffmpeg -y -f concat -safe 0 -i concat.txt -c copy 03-gaming-creatures.mp4
```

Simple concat — no transitions, no re-encoding. Each clip flows into the next.

## Key Learnings

1. **Mood board as anchor** — sending the mood board as `--edit` reference to Gemini keeps the style ultra-consistent across all frames
2. **"Single scene, full frame, no panels"** — critical prefix to prevent Gemini from generating another mood board layout
3. **Ambient-only Sora prompts** — "subtle ambient motion" + specific effects (flicker, pulse, twinkle) + "no new objects, preserve exact art style" = pixel-perfect animation
4. **Character naming in prompts** — describing each character by their accessories (not just "creature") helps Gemini place the right ones in scene
5. **16-bit retro game framing** — adding UI elements (score, health bars, lives) sells the game aesthetic instantly
6. **Concat over re-encode** — ffmpeg concat copies streams directly, no quality loss, instant

## TODO

- [ ] Recover Pac-Man creatures video from Sora drafts (re-login needed)
- [ ] Try 10s (300 frames) versions for the best clips
- [ ] Add Kokoro TTS narration or MusicGen retro soundtrack
- [ ] Try portrait versions for Instagram/TikTok
