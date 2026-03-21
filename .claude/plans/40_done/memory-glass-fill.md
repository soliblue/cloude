# Memory Glass Fill Background {drop.fill}
<!-- priority: 10 -->
<!-- tags: ui, memory -->
<!-- build: 65 -->

> Replaced memory usage progress bar with a glass-of-water fill effect on the sheet background. The entire Memories sheet background fills from the bottom based on usage percentage — at 28% usage, the bottom 28% has a subtle gradient tint.

## Changes
- Removed `MemoryUsageIndicator` view (capsule progress bar)
- Added `LinearGradient` background that fills from bottom based on `usagePercent`
- Gradient fades from transparent at top to `usageColor.opacity(0.1)` at bottom (soft water surface)
- Kept text-only "14.3K / 50K" label in toolbar trailing position
- Color still shifts orange at 80% and red at 95%

## Files
- `Cloude/Cloude/UI/MemoriesSheet.swift`
