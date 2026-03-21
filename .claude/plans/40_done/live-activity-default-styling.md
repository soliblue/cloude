# Live Activity Default Styling {livephoto}
<!-- priority: 10 -->
<!-- tags: ui, theme -->
<!-- build: 67 -->

> Removed custom accent and forced backgrounds from Live Activity, using system defaults.

## Changes
- Removed `Color.cloudeAccent` custom color
- Removed `.activityBackgroundTint(.white)` from lock screen
- Icons use `.tint` (system accent) instead of custom orange
- Conversation name uses default label color
- State indicators use `.secondary` instead of hard green/orange
- Compact running state uses spinner instead of green pulsing bolt

## File
- `Cloude/CloudeLiveActivity/CloudeLiveActivity.swift`
