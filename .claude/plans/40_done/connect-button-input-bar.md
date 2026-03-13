# Connect Button in Input Bar

## Problem
When opening a chat whose environment is disconnected, the only way to reconnect was through settings. Too many taps for a common action.

## Changes
- **GlobalInputBar.swift**: Added `isEnvironmentDisconnected` and `onConnect` params
- **GlobalInputBar+ActionButton.swift**: Show power button (orange) when env is disconnected, replacing send button
- **MainChatView.swift**: Pass disconnected state and reconnect callback

## Behavior
- Power button shows when env has credentials but isn't authenticated
- Tap calls `reconnect()` on the environment connection
- Once authenticated, transitions back to normal send button
- If env has no credentials (never configured), normal send button shows
