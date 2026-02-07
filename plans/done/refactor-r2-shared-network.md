# Refactor R2: Move NetworkHelper to CloudeShared

## Status: Active

## Problem
`NetworkHelper` is duplicated across both targets:
- `Cloude/Cloude/Utilities/Network.swift`
- `Cloude/Cloude Agent/Utilities/Network.swift`

Nearly identical implementations. Both used for IP address display.

## Fix
- Move to `CloudeShared/Sources/CloudeShared/Extensions/NetworkHelper.swift`
- Delete both target-specific copies
- Both targets already import CloudeShared
