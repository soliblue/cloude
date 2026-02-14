# Skill Execution UI
<!-- priority: 10 -->
<!-- tags: skills, ui -->
<!-- build: 56 -->

Show more information when a skill is executed, instead of the generic "Skill" pill with a gear icon.

## Problem

When Claude executes a skill (via the Skill tool), the iOS app renders a minimal grey pill that just says "Skill" with a gear icon. No indication of:
- Which skill is running (e.g., "plan", "deploy", "push")
- What arguments were passed
- What it's doing

Users see a blank pill and have no context until the skill finishes and output appears.

## Goals
- Show the skill name in the pill (e.g., "plan" instead of "Skill")
- Show arguments/description if available (e.g., "plan: create backlog adaptive-thinking-support")
- Use a more specific icon per skill if possible, or at least show the skill name prominently

## Approach
- The Skill tool call includes `skill` and optional `args` parameters in the tool input
- Parse these from the tool_use content block and display in the UI
- Could show as "Skill: plan" or just "plan" with a subtitle for args
- Consider a small expandable section or subtitle text under the pill

## Files
- `Cloude/UI/ChatView.swift` or related message rendering components — update tool pill rendering
- `Cloude/Models/Messages.swift` — may need to parse skill name/args from tool input

## Notes
- Same pattern could improve other tool pills too (show file paths for Read, show commands for Bash, etc.)
- Keep it concise — don't dump raw JSON, just the meaningful bits
- Screenshot of current state: generic grey pill with gear icon and "Skill" text
