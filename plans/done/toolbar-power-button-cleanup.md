# Toolbar Power Button Cleanup
<!-- build: 60 -->

## Changes
1. **Power button icon**: Replaced colored red/green icons with a single `power` SF Symbol that lights up with accent color when connected and dims to `.secondary` when disconnected
2. **Settings moved to left**: Gear icon moved from right toolbar group to left group (with plans + memories). Right side now has only the power button

## Files Changed
- `Cloude/Cloude/App/CloudeApp.swift` — toolbar layout restructured

## Test
- [ ] Power button shows accent color when connected
- [ ] Power button shows gray when disconnected
- [ ] Tapping power button toggles connection
- [ ] Settings gear appears on left side with plans/memories
- [ ] Right side has only power button
