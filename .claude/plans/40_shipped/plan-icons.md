---
title: "Plan Icons — SF Symbols for Plan Titles"
description: "SF Symbol icons in plan headings, displayed on plan cards — same `{icon}` pattern as memory sections."
created_at: 2026-02-08
tags: ["plans", "ui"]
icon: doc.badge.gearshape
build: 52
---

# Plan Icons — SF Symbols for Plan Titles
Add SF Symbol icon support to plan files, matching the memory section `{icon}` pattern.

## Format
Plans use frontmatter `icon: sf.symbol.name` plus `# Title {sf.symbol.name}` in the markdown heading.

## Changes
- `PlanItem` model: added `icon: String?` field
- `PlansService`: extracts `icon` from frontmatter and also reads `{icon}` from the `# Title {icon}` heading
- `PlanCard`: shows icon left of title when present (accent color, 18pt)
- `PlansService.stages`: added "done", reordered to backlog → next → active → testing → done
- `PlansSheet.stageOrder`: matched new order, replaced text labels with SF Symbol stage icons
