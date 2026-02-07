---
name: test
description: Show what needs testing and update staging after tests pass. Use when asked "what needs testing", "test", or to confirm tests passed.
user-invocable: true
icon: checkmark.diamond
aliases: [check, testing]
---

# Test Skill

Manage the testing workflow. The `plans/testing/` folder is the source of truth for what needs testing.

## Show What Needs Testing

List all plan files in `plans/testing/`. For each item, explain:
- What the feature does
- How to test it
- What success looks like

## After Testing

When Soli confirms items pass:

1. Move the plan file from `plans/testing/` to `plans/done/`
2. If all items tested, suggest deploying

## Blocking Rule

If 5+ items in `plans/testing/`:
- Don't add new features
- Tell Soli to test first
- Focus on bug fixes or docs only

## After Deploy

Update "Last deploy" timestamp in CLAUDE.local.md staging section.
