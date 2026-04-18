---
title: "Plan Metadata"
description: "Plan front matter shape for title, description, created_at, tags, icon, and inferred build metadata."
created_at: 2026-02-08
tags: ["ui", "plans"]
icon: tag.fill
build: 54
---


# Plan Metadata {tag.fill}
## Format

YAML front matter in plan files for machine-readable metadata:

```markdown
---
title: "My Plan"
description: "Human-readable description here"
created_at: 2026-02-08
tags: ["ui", "heartbeat"]
icon: sparkles
build: 54
---

# My Plan {sparkles}
```

## Features

### Created Date
- `created_at: YYYY-MM-DD` captures the first known git day for the plan file
- Stays stable even when the plan moves between folders
- Lets the file keep its origin date without encoding lifecycle state in metadata

### Tags & Categories
- `tags: ["ui", "security", "heartbeat"]` for categorization
- Suggested categories: `ui`, `agent`, `security`, `reliability`, `heartbeat`, `memory`, `autonomy`
- Filter chips in PlansSheet to show/hide by tag
- Color-coded pills on plan cards

### Build Tagging
- `build: 54` records the app build configured in the repo when the plan file first landed
- Inferred from the plan file's first commit and `CURRENT_PROJECT_VERSION` in `Cloude.xcodeproj`
- Lets the file keep a coarse app-era marker even if it later moves between folders
- Useful for "what build context did this plan originate in?" queries

## Files
- `Cloude/Cloude/Models/PlansService.swift` — parse plan front matter
- `Cloude/Cloude/UI/PlansSheet.swift` — sorting, filtering, drag-and-drop, tag pills, build badges
- `fastlane/Fastfile` — auto-tag done plans at deploy time
