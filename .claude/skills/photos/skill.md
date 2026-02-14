---
name: photos
description: Access Apple Photos library. List albums, get recent photos, export by date/album. Photos sync from iPhone via iCloud.
user-invocable: true
icon: photo.on.rectangle
aliases: [photo, pictures, gallery]
---

# Apple Photos Skill

Access Photos.app via AppleScript. List albums, browse recent photos, export images to /tmp for viewing. iPhone photos sync via iCloud and are accessible here.

## First-Time Setup

Run any script once to trigger the macOS permission dialog:
```bash
bash .claude/skills/photos/photos-albums.sh
```
Click "Allow" in System Settings → Privacy & Security → Automation → Terminal → Photos.

## Scripts

### List albums
```bash
bash .claude/skills/photos/photos-albums.sh
```

### List recent photos
```bash
bash .claude/skills/photos/photos-recent.sh              # Last 10 photos
bash .claude/skills/photos/photos-recent.sh 25             # Last 25 photos
```
Returns metadata only (name, date, dimensions). Use export to get actual images.

### Export photos to /tmp
```bash
bash .claude/skills/photos/photos-export.sh 5                          # Export last 5 photos
bash .claude/skills/photos/photos-export.sh 3 "Vacation 2025"          # From specific album
```
Exports to `/tmp/cloude-photos/`. Use the Read tool on exported files to view them.

### Search photos by date
```bash
bash .claude/skills/photos/photos-by-date.sh "2026-02-14"              # Photos from a specific day
bash .claude/skills/photos/photos-by-date.sh "2026-02-14" 10           # With limit
```

## Output Format

Photo listing:
```
ID|Name|Date|Width|Height
```

Export:
```
Exported 5 photos to /tmp/cloude-photos/
```

## Notes
- Photos.app AppleScript is slow on large libraries (~40s for big collections)
- Cannot search by content/faces (no "find photos of Mom") — only by date, album, name
- Cannot delete or edit photos
- Export creates copies in /tmp — originals are never modified
- Exported files are overwritten on next export (no disk accumulation)

## Security
- Read-only access to the Photos library
- Exports go to /tmp only, never to project directory
- No photos are committed to git or stored permanently
