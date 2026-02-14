---
name: notes
description: Access the user's Apple Notes — diary entries, ideas, philosophy, writings. 328+ diary entries from 2014-2025. Exported as markdown for search and analysis.
user-invocable: true
icon: note.text
aliases: [diary, journal]
---

# Apple Notes Skill

Access the user's personal notes exported from Apple Notes. Includes diary entries (2014-2025), ideas, philosophy, writings, and more.

## Setup (First Time)

Export all notes from Apple Notes to markdown:
```bash
bash .claude/skills/notes/export.sh
```

Export a single folder only:
```bash
bash .claude/skills/notes/export.sh "Diary"
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
grep -rl "keyword" .claude/skills/notes/data/ --include="*.md"
```

### Read a specific note
Use the Read tool with the full path to the markdown file.

### List all diary entries
```bash
ls .claude/skills/notes/data/Diary/
```

### Search diary by date range
```bash
ls .claude/skills/notes/data/Diary/ | grep "^2024"
```

### Full-text search across all notes
```bash
grep -rli "therapy\|therapist" .claude/skills/notes/data/ --include="*.md"
```

## Creating Notes via AppleScript

You can create and edit notes directly in Apple Notes via AppleScript:

```applescript
tell application "Notes"
    set targetFolder to first folder whose name is "Notes"
    make new note at targetFolder with properties {name:"My Note", body:"<div><b>Bold header</b></div><div>• Bullet point</div>"}
end tell
```

### Formatting that works reliably
- `<h1>Title</h1>` — large title (collapsible in Notes)
- `<h2>Section</h2>` — section heading (collapsible in Notes)
- `<h3>Subsection</h3>` — sub-heading (collapsible in Notes)
- `<b>text</b>` — bold
- `<i>text</i>` — italic
- `<u>text</u>` — underline
- `<strike>text</strike>` — strikethrough (great for marking items done)
- `<ul><li>item</li></ul>` — bullet list
- `<div>` — line/paragraph breaks
- `<br>` for line breaks within a div

### What does NOT work or is unreliable
- Clickable links (`<a href>`) — technically work but AppleScript can't read them back reliably, creates messy HTML. Let the user add links manually in the UI.
- Checklist/checkbox creation — Apple locks this to manual UI only
- `font-size` styles — avoid entirely, causes inconsistent rendering

### Best practice
Use `<h2>` for collapsible section headers, `<h3>` for sub-sections, `<ul><li>` for bullets, `<strike>` for done items. For URLs, just write plain text (e.g., "jardinmajorelle.com") — the user can tap and add the link manually if needed. Do NOT mix heading tags with `font-size` or `<b>` wrappers — use them standalone.

## Privacy

This is the user's personal diary. The data directory is gitignored and never committed. Treat the content with care — it contains deeply personal reflections, relationships, and experiences.

## Use Cases

- **Interview context**: Reference diary entries when discussing life events, verify timeline
- **Pattern analysis**: Track themes, emotional arcs, recurring topics over 10+ years
- **Memory building**: Extract key moments and insights for CLAUDE.local.md
- **Writing voice**: Understand the user's personal writing style (vs. professional/tweet voice)
- **Timeline verification**: Cross-reference dates and events mentioned in conversation
