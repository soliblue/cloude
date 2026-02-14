---
name: safari
description: Access Safari tabs, bookmarks, reading list, and history. Browse what's open, search past visits, find saved links.
user-invocable: true
icon: safari
aliases: [browser, tabs, bookmarks, history]
---

# Safari Browser Skill

Read-only access to Safari via AppleScript and local SQLite/plist files. No external dependencies — uses only built-in macOS tools.

## First-Time Setup

Run any script once from Terminal to trigger the macOS permission dialog:
```bash
bash .claude/skills/safari/safari-tabs.sh
```
Click "Allow" in System Settings -> Privacy & Security -> Automation -> Terminal -> Safari.

For history access, grant Full Disk Access to Terminal in System Settings -> Privacy & Security -> Full Disk Access.

## Scripts

### List open tabs
```bash
bash .claude/skills/safari/safari-tabs.sh
```
Shows all open tabs across all Safari windows, marking the active tab.

### Search history
```bash
bash .claude/skills/safari/safari-history.sh "claude"        # Search for "claude", last 20 results
bash .claude/skills/safari/safari-history.sh "github" 50      # Search with custom limit
bash .claude/skills/safari/safari-history.sh "" 10             # Last 10 visited pages (no filter)
```

### List/search bookmarks
```bash
bash .claude/skills/safari/safari-bookmarks.sh                # All bookmarks
bash .claude/skills/safari/safari-bookmarks.sh "anthropic"    # Search bookmarks
```

### Show Reading List
```bash
bash .claude/skills/safari/safari-readinglist.sh
```

## Output Formats

Tabs:
```
Window#|Tab#|Active|Title|URL
```

History:
```
Date|Title|URL
```

Bookmarks:
```
Title|URL|Folder
```

Reading List:
```
Title|URL|DateAdded|Unread
```

## Use Cases
- "What tabs do I have open?"
- "Did I visit that article about X recently?"
- "Find my bookmarked links about SwiftUI"
- "What's on my reading list?"
- "What was that website I visited yesterday?"

## Security
- All operations are read-only
- History access requires Full Disk Access for Terminal
- No data leaves the Mac — pure local access
