# Plan Description Field {text.below.photo}

> Show a 2-3 line description on plan cards without opening them.

## Problem
Plan cards in PlansSheet only show the title. You have to tap into a plan to know what it's about. A short description preview would make scanning plans much faster.

## Format
Plans use a `> blockquote` line(s) right after the `# Title {icon}` heading as the description:

```markdown
# My Plan {icon}

> Short 1-3 line description of what this plan does
> and why it matters.
```

## Changes

### Model
- `PlanItem`: add `description: String?` field

### Service
- `PlansService`: extract blockquote lines after heading as description (lines starting with `> `)

### UI
- `PlanCard` in `PlansSheet.swift`: show description below title in `.secondary` color, `.caption` font, max 3 lines
- Card layout: icon + title inline on same row (HStack), description on row below — no more icon taking a full column

## Files
- `Cloude/Cloude/Models/PlansService.swift` — parse description
- `Cloude/Cloude/UI/PlansSheet.swift` — render description on card
