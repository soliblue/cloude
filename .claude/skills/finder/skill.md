---
name: finder
description: Search files using Spotlight (mdfind). Faster than find/grep — searches by name, content, kind, date. Uses macOS Spotlight index.
user-invocable: true
icon: magnifyingglass
aliases: [spotlight, search, find, mdfind]
---

# Finder / Spotlight Skill

Search files across the entire Mac using Spotlight's index (`mdfind`). Instant results — searches metadata, file names, and content.

## Usage

```bash
bash .claude/skills/finder/search.sh "tax return"                     # Search everywhere
bash .claude/skills/finder/search.sh "invoice" ~/Documents             # Search specific folder
bash .claude/skills/finder/search.sh "kind:pdf budget"                 # PDFs only
bash .claude/skills/finder/search.sh "kind:image date:2026-02"         # Images from Feb 2026
bash .claude/skills/finder/search.sh "kind:presentation"               # Keynote/PowerPoint files
```

### Quick searches by kind
```bash
bash .claude/skills/finder/search.sh "kind:pdf"           # PDFs
bash .claude/skills/finder/search.sh "kind:image"         # Images
bash .claude/skills/finder/search.sh "kind:document"      # Documents
bash .claude/skills/finder/search.sh "kind:spreadsheet"   # Spreadsheets
bash .claude/skills/finder/search.sh "kind:audio"         # Audio files
bash .claude/skills/finder/search.sh "kind:video"         # Videos
bash .claude/skills/finder/search.sh "kind:folder"        # Folders
```

## Notes
- Uses macOS Spotlight index — results are instant even across millions of files
- Searches file names, content, and metadata
- No permissions needed (uses same index as Spotlight/Cmd+Space)
- Results limited to 50 by default to avoid flooding context
