# Complementary Color for Active Tab

## Goal
Add a complementary color to the orange used throughout the app, specifically to highlight the active window tab in the bottom page indicator.

## Design
- Current: active tab uses `.accentColor` (blue)
- Proposal: use a color complementary to `.orange` — candidates:
  - Blue `#0066FF` (true complementary)
  - Teal/Cyan (split-complementary, may feel fresher)
- Apply to active window dot/icon in `MainChatView+PageIndicator.swift`

## Scope
- Define the complementary color as a reusable asset
- Update `windowIndicatorIcon` active state styling
- Ensure it works well in both light and dark mode
