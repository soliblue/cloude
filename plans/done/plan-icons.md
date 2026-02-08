# Plan Icons — SF Symbols for Plan Titles {doc.badge.gearshape}

> SF Symbol icons in plan headings, displayed on plan cards — same `{icon}` pattern as memory sections.

Add SF Symbol icon support to plan files, matching the memory section `{icon}` pattern.

## Format
Plans use `# Title {sf.symbol.name}` in the markdown heading, same as memory sections.

## Changes
- `PlanItem` model: added `icon: String?` field
- `PlansService`: extracts `{icon}` from `# Title {icon}` heading using same regex as MemoryParser
- `PlanCard`: shows icon left of title when present (accent color, 18pt)
- `PlansService.stages`: added "done", reordered to backlog → next → active → testing → done
- `PlansSheet.stageOrder`: matched new order, replaced text labels with SF Symbol stage icons
