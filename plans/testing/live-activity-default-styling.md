# Live Activity Default Styling

Removed custom orange accent color and forced backgrounds from Live Activity indicators. Now uses system default colors throughout.

## Changes
- Removed `Color.cloudeAccent` custom color
- Removed `.activityBackgroundTint(.white)` from lock screen
- Icons use `.tint` (system accent) instead of custom orange
- Conversation name uses default label color
- State indicators use `.secondary` instead of hard green/orange
- Compact running state uses spinner instead of green pulsing bolt

## File
- `Cloude/CloudeLiveActivity/CloudeLiveActivity.swift`
