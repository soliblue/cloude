# Disable File Preview When Disconnected

## Summary
File path pills in chat and plans sheet file links now do nothing when the environment is not connected, matching the pattern of other disabled UI elements (send button, terminal tab, etc.).

## Changes
- `CloudeApp.swift`: Guarded `onOpenURL` file handler with `isAuthenticated` check
- `CloudeApp.swift`: Guarded plans sheet `onOpenFile` callback with `isAuthenticated` check

## Test
1. Disconnect from environment
2. Open a conversation that has file path pills in messages
3. Tap a file path pill - should do nothing
4. Connect to environment
5. Tap the same pill - should open file preview
