# Plan Metadata {tag.fill}
<!-- priority: 1 -->
<!-- tags: ui, plans -->

> Unified plan metadata system: priority ordering, tags/categories, build tagging, and drag-and-drop reordering in the Plans UI.

## Format

HTML comments in plan files for machine-readable metadata:

```markdown
# My Plan {icon}
<!-- priority: 5 -->
<!-- tags: ui, heartbeat -->
<!-- build: 54 -->

> Human-readable description here
```

## Features

### Priority Ordering
- `<!-- priority: N -->` field in each plan file
- Plans UI sorts by priority within each stage
- Drag-and-drop in Plans UI writes new priority numbers back to the file
- No filename prefixes — ordering lives in the file, not the name

### Tags & Categories
- `<!-- tags: ui, security, heartbeat -->` for categorization
- Suggested categories: `ui`, `agent`, `security`, `reliability`, `heartbeat`, `memory`, `autonomy`
- Filter chips in PlansSheet to show/hide by tag
- Color-coded pills on plan cards

### Build Tagging
- `<!-- build: 54 -->` stamped when a plan moves to done
- Deploy lane auto-tags all untagged done plans with current build number
- Enables "what shipped in Build X?" queries
- Show build number as small badge on done plan cards

## Files
- `Cloude/Cloude/Models/PlansService.swift` — parse HTML comment metadata
- `Cloude/Cloude/UI/PlansSheet.swift` — sorting, filtering, drag-and-drop, tag pills, build badges
- `fastlane/Fastfile` — auto-tag done plans at deploy time
