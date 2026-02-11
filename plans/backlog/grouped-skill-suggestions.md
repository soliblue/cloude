# Grouped Skill Suggestions

## Problem
When typing `/`, skills show as a flat horizontal scroll of pills. With 20+ skills, this is hard to scan — no hierarchy, no grouping, just a wall of pills.

## Idea
Group skills into categories and show them in a more organized way. Instead of flat pills, show grouped sections like:

- **Media**: speak, music, video, image, slides, recap
- **Info**: status, notes, goodreads, tweets, manifold
- **Dev**: push, deploy, test, refactor, plan
- **Social**: moltbook, consult
- **Meta**: reflect, skillsmith, icon

## Approach Options

### Option A: Sectioned horizontal scroll
Keep the horizontal scroll but add small group headers (gray labels like "Media", "Dev") with pills grouped underneath. Simple extension of current UI.

### Option B: Grid/sheet
Tapping `/` opens a bottom sheet with a grid of skills organized by category. More discoverable, more room for descriptions. Like the emoji keyboard but for skills.

### Option C: Two-tier pills
First show category pills (Media, Dev, Info...), tapping one expands to show the skills in that category. Compact but interactive.

## Data Model Change
Need a `category` or `group` field on `Skill` (or a client-side mapping). Could be:
- Server-side: add `group: String?` to Skill model, set in SKILL.md metadata
- Client-side: hardcoded mapping from skill name → group (simpler, no protocol change)

## Notes
- Current model: `SlashCommand` has name, description, icon, isSkill
- `Skill` has name, description, userInvocable, icon, aliases, parameters
- Neither has a group/category field yet
- Filter should still work — typing `/sp` should still narrow to `speak`, `slides` etc regardless of grouping
