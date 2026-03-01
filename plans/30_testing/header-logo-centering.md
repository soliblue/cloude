# Header Logo Centering

## Problem
Cloude logo in navigation bar was not centered — 3 buttons on the left and 1 on the right made iOS push the `.principal` item off-center.

## Solution
- Moved power button to the left (first position, before brain/plans/clock)
- Moved Cloude logo from `.principal` to `.topBarTrailing`
- Layout: `power | brain | clipboard | clock` on left, logo on right
- Removed hardcoded offset hack from empty state character

## Files Changed
- `Cloude/Cloude/App/CloudeApp.swift` — toolbar button rearrangement
- `Cloude/Cloude/UI/ConversationView+EmptyState.swift` — removed offset
