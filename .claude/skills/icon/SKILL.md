---
name: icon
description: Alias for the icon pipeline implemented under `.claude/skills/image/icon/` (kept for backwards compatibility).
user-invocable: true
disable-model-invocation: true
icon: photo.badge.plus
aliases: [icongen, app-icon]
parameters:
  - name: description
    placeholder: Describe the icon...
    required: true
---

# Icon Generation Skill

This skill is intentionally thin: it’s an alias to the real implementation at `.claude/skills/image/icon/`.

## Commands

```bash
source .claude/skills/image/icon/.venv/bin/activate

GOOGLE_API_KEY=$GOOGLE_API_KEY python .claude/skills/icon/generate.py \
  --prompt "description of icon" \
  --output icon_name \
  --assets-dir Cloude/Cloude/Assets.xcassets
```

## Options

- See `.claude/skills/image/icon/generate.py --help`

## Notes

- GOOGLE_API_KEY must be set (available in environment)
- Output goes to `.claude/skills/image/output/icons/` by default
- With `--assets-dir`, creates proper `.imageset` folder with Contents.json
