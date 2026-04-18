---
title: "Plan Description Field"
description: "Show a 2-3 line description on plan cards without opening them."
created_at: 2026-02-08
tags: ["ui"]
icon: text.below.photo
build: 53
---

# Plan Description Field {text.below.photo}
## Problem
Plan cards in PlansSheet only show the title. You have to tap into a plan to know what it's about. A short description preview would make scanning plans much faster.

## Format
Plans now store the summary in frontmatter `description`, for example:

```markdown
---
title: "My Plan"
description: "Short 1-3 line description of what this plan does and why it matters."
created_at: 2026-02-08
tags: ["ui"]
icon: text.below.photo
---

# My Plan {text.below.photo}
```

## Changes

### Model
- `PlanItem`: add `description: String?` field

### Service
- `PlansService`: read `description` from frontmatter

### UI
- `PlanCard` in `PlansSheet.swift`: show description below title in `.secondary` color, `.caption` font, max 3 lines
- Card layout: icon + title inline on same row (HStack), description on row below - no more icon taking a full column

## Files
- `Cloude/Cloude/Models/PlansService.swift` - parse description
- `Cloude/Cloude/UI/PlansSheet.swift` - render description on card
