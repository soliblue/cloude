# Environment Icons in Toolbar
<!-- build: 86 -->

## Summary
Show all environment SF Symbol icons in the navigation bar toolbar (between settings logo and power button). Connected environments get accent color, connecting ones pulse, disconnected ones are dimmed.

## Changes
- `CloudeApp.swift` - replaced `navTitlePill` with `environmentIndicators` view showing all env icons with connection state coloring
- `MainChatView+Windows.swift` - removed single env symbol from window header (now redundant)

## Notes
- Connected (authenticated) = accent color, semibold
- Connecting (isConnected but not authenticated) = accent color + pulse animation
- Disconnected = secondary at 0.4 opacity
- Conversation name/cost info was already shown in the window header via `ConversationInfoLabel`
