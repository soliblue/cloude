# Android Scroll Position Preservation {arrow.up.and.down}
<!-- priority: 14 -->
<!-- tags: android, ux, polish -->

> Preserve scroll position when switching between window tabs.

## Desired Outcome
Switching between Chat/Files/Git tabs should preserve scroll position in each tab instead of resetting to top. Tabs stay mounted but hidden.

## iOS Reference Architecture

### Components
- `WorkspaceView+Windows.swift` - uses opacity toggling instead of conditional rendering

### Android implementation notes
- `HorizontalPager` with `beyondViewportPageCount = 1` already keeps adjacent pages alive
- But switching window types (Chat/Files/Git) may recreate composables
- Use `rememberLazyListState()` keyed per window+type to preserve scroll
- Or keep all three tab types mounted with visibility toggling

**Files (iOS reference):** WorkspaceView+Windows.swift
