# Team Orbs Speech Bubble Alignment {bubble.right}

> Orbs shift left when a teammate sends a message — speech bubble expands the HStack instead of growing leftward from a right-aligned anchor.

## Problem
When a teammate's speech bubble appears, the orb circles shift left to accommodate the bubble width. The orbs should stay pinned to the right edge and the speech bubble should grow leftward.

## Root Cause
`TeamOrbsOverlay`'s outer `VStack` (line 14) and `TeammateOrbRow`'s `HStack` (line 45) don't specify `.trailing` alignment. The default `.center` alignment causes the orb to shift left when the bubble appears.

## Fix
- `VStack(alignment: .trailing, spacing: 12)` on the outer container
- `HStack(spacing: 6)` already fine — the VStack alignment pins the row's trailing edge
- Possibly need `.frame(maxWidth: .infinity, alignment: .trailing)` on the overlay

## Files
- `Cloude/Cloude/UI/TeamOrbsOverlay.swift`
