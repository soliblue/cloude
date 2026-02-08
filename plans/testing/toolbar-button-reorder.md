# Toolbar Button Reorder
<!-- build: 61 -->

Swapped Settings and Plans button positions in the main toolbar.

**Before**: Plans | Memories | Settings ... [Logo] ... Power
**After**: Settings | Memories | Plans ... [Logo] ... Power

Logo uses `.principal` placement which centers it in the navigation bar between the leading and trailing toolbar items.

## Changes
- `CloudeApp.swift` — Reordered toolbar buttons in `.topBarLeading` group
