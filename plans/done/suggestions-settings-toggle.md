# Suggestions Settings Toggle

**Status**: Testing

Added a toggle in Settings > Features to enable/disable smart reply suggestions. Default is off.

## Changes
- `SettingsView.swift`: New "Features" section with "Smart Suggestions" toggle (`@AppStorage("enableSuggestions")`, default `false`)
- `MainChatView.swift`: `requestSuggestions()` gated on `enableSuggestions`

## Test
- Toggle off (default): no suggestion bubbles appear after agent finishes
- Toggle on: suggestion bubble appears above input bar after agent finishes
