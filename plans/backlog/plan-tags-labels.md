# Plan Tags & Labels {tag.fill}

> Explore adding 2-3 tags per plan for filtering and categorization in the Plans UI.

## Goal
Plans currently live in stage folders (backlog, active, testing, done) but have no secondary categorization. Tags would let you quickly filter by area — e.g. show only UI plans, or only heartbeat-related work.

## Open Questions
- What tags make sense? Some candidates:
  - **Area**: `ui`, `agent`, `infra`, `security`, `memory`, `heartbeat`
  - **Type**: `feature`, `bugfix`, `refactor`, `cleanup`
  - **Priority**: `p0`, `p1`, `p2`
  - **Size**: `small`, `medium`, `large`
- Format in markdown: `tags: ui, feature` line after the heading? Or inline like `{icon} [ui] [feature]`?
- UI: filter chips at the top of PlansSheet? Color-coded pills on each card?
- How many tags per plan? 2-3 feels right — enough to categorize without overcomplicating

## Notes
- Keep it simple — tags should be freeform strings, not a rigid taxonomy
- The value is in quick filtering, not perfect categorization
