# Move DS Tokens to CloudeShared {square.3.layers.3d}
<!-- priority: 7 -->
<!-- tags: refactor, agent, ui -->

> DS enum lives in iOS target only — move to CloudeShared so Mac agent and LiveActivity can use tokens too.

## Background
DS tokens (spacing, scale, duration, size, etc.) are defined in Theme.swift inside the iOS app target. The Mac agent and CloudeLiveActivity extension import CloudeShared but can't access DS. This means hardcoded numbers in those targets can't be tokenized.

## Goals
- All 3 targets (iOS, Mac agent, LiveActivity) share one DS enum
- Tokenize remaining hardcoded numbers in agent + LiveActivity files

## Approach
1. Extract `enum DS` from Theme.swift into a new `DesignTokens.swift` in CloudeShared
2. Keep Theme.swift palette/SwiftUI stuff in iOS target (it has SwiftUI dependencies)
3. Add missing tokens: `DS.Text.xs` (9), `DS.Text.caption` (11), `DS.Size.indicator` (8), `DS.Scale.mini` (0.5), `DS.Duration.sample` (0.05), `DS.Duration.confirm` (2.0), `DS.Duration.refresh` (3.0)
4. Replace hardcoded numbers in StatusView, StatusView+Sections, CloudeLiveActivity, LockScreen

## Files
- `CloudeShared/Sources/CloudeShared/DesignTokens.swift` (new)
- `Cloude/Utilities/Theme.swift` (remove DS enum, import from shared)
- `Cloude Agent/UI/StatusView.swift`
- `Cloude Agent/UI/StatusView+Sections.swift`
- `CloudeLiveActivity/CloudeLiveActivity.swift`
- `CloudeLiveActivity/CloudeLiveActivity+LockScreen.swift`

## Open Questions
- Should Mac popover dimensions (280, 300x400) be tokens or left as platform-specific constants?
