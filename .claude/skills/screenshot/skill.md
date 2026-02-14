---
name: screenshot
description: Capture the Mac's screen. Full screen, specific window, or region. Returns the image for visual analysis.
user-invocable: true
icon: camera.viewfinder
aliases: [screen, capture, laptop-screen]
---

# Screenshot Skill

Capture what's on the Mac screen using macOS built-in `screencapture`. Returns the image for Claude to read and analyze visually.

## First-Time Setup

Grant screen recording permission:
System Settings → Privacy & Security → Screen Recording → enable for Terminal (and Cloude Agent if applicable).

## Usage

```bash
bash .claude/skills/screenshot/capture.sh              # Full screen
bash .claude/skills/screenshot/capture.sh window        # Front window only
```

Then read the image:
```bash
# Use the Read tool on the output path to see the screenshot
```

## Output

Screenshots saved to `/tmp/cloude-screenshot.png` (overwritten each time — no disk accumulation).

## Notes
- `-x` flag suppresses shutter sound
- Display must be awake (fails if lid closed / screen asleep)
- No data leaves the Mac — image stays in /tmp
