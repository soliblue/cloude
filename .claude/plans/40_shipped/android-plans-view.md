---
title: "Android Plans View"
description: "View plan tickets grouped by stage from the app."
created_at: 2026-03-30
tags: ["android", "plans"]
build: 120
icon: list.bullet.clipboard
---
# Android Plans View {list.bullet.clipboard}


## Desired Outcome
Display plans grouped by stage (backlog, next, active, testing, done). Plan cards with title, icon, description, priority, tags. Tap to view details. Delete plans.

## iOS Reference Architecture

### Data flow
1. Server sends `ServerMessage.Plans` containing list of `PlanItem` objects
2. Each `PlanItem` has: title, description, icon (SF Symbol), priority, tags, stage

### UI structure
- `CloudeApp+PlansSheet.swift` - modal sheet with stage sections as expandable groups
- `CloudeApp+PlansSheet+Components.swift` - stage section headers with icon, name, item count, color coding per stage
- `CloudeApp+PlansSheet+PlanCard.swift` - individual plan card with icon, title, description preview, priority badge, tag chips
- Stages have distinct colors: backlog (gray), next (blue), active (orange), testing (purple), done (green)
- Delete action via swipe or context menu

### Android implementation notes
- `ModalBottomSheet` with `LazyColumn` and sticky headers per stage
- Map SF Symbol names to Material Icons for plan icons
- Stage colors via `MaterialTheme.colorScheme` variants
- `ServerMessage.Plans` already handled in message parsing (needs UI)
- Request plans via `ClientMessage` on sheet open

**Files (iOS reference):** CloudeApp+PlansSheet.swift (+Components, +PlanCard)
