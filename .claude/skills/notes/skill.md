---
name: notes
description: Access Soli's Apple Notes — diary entries, ideas, philosophy, writings. 328+ diary entries from 2014-2025. Exported as markdown for search and analysis.
user-invocable: true
icon: note.text
aliases: [diary, journal]
---

# Apple Notes Skill

Access Soli's personal notes exported from Apple Notes. Includes diary entries (2014-2025), ideas, philosophy, writings, and more.

## Setup (First Time)

Export all notes from Apple Notes to markdown:
```bash
bash /Users/soli/Desktop/CODING/cloude/.claude/skills/notes/export.sh
```

Export a single folder only:
```bash
bash /Users/soli/Desktop/CODING/cloude/.claude/skills/notes/export.sh "Diary"
```

Requires Apple Notes permission for Terminal (System Settings → Privacy → Automation).

## Re-export

Run the export script again to refresh. It overwrites existing files.

## Data Location

```
.claude/skills/notes/data/           # All exported notes (gitignored)
.claude/skills/notes/data/Diary/     # Diary entries
.claude/skills/notes/data/Ideas/     # Ideas
.claude/skills/notes/data/Philosophy/ # Philosophy
.claude/skills/notes/data/Writings/  # Writings
...etc per folder
```

Each note is a markdown file with YAML frontmatter:
```yaml
---
title: 📔20250411 - 29th Birthday with Mahmoud & Solveg
created: 2025-05-05
modified: 2025-05-05
folder: Diary
---
```

## Folders

| Folder | Description |
|--------|-------------|
| Diary | Personal diary entries, 328+ notes from 2014-2025 |
| Ideas | Ideas and concepts |
| Philosophy | Philosophical reflections |
| Writings | Longer-form writing |
| Spanish | Spanish language notes |
| Notes | General notes |
| Unclassified | Uncategorized |

## Common Operations

### Search notes by keyword
```bash
grep -rl "keyword" /Users/soli/Desktop/CODING/cloude/.claude/skills/notes/data/ --include="*.md"
```

### Read a specific note
Use the Read tool with the full path to the markdown file.

### List all diary entries
```bash
ls /Users/soli/Desktop/CODING/cloude/.claude/skills/notes/data/Diary/
```

### Search diary by date range
```bash
ls /Users/soli/Desktop/CODING/cloude/.claude/skills/notes/data/Diary/ | grep "^2024"
```

### Full-text search across all notes
```bash
grep -rli "therapy\|therapist" /Users/soli/Desktop/CODING/cloude/.claude/skills/notes/data/ --include="*.md"
```

## Privacy

This is Soli's personal diary. The data directory is gitignored and never committed. Treat the content with care — it contains deeply personal reflections, relationships, and experiences.

## Use Cases

- **Interview context**: Reference diary entries when discussing life events, verify timeline
- **Pattern analysis**: Track themes, emotional arcs, recurring topics over 10+ years
- **Memory building**: Extract key moments and insights for CLAUDE.local.md
- **Writing voice**: Understand Soli's personal writing style (vs. professional/tweet voice)
- **Timeline verification**: Cross-reference dates and events mentioned in conversation
