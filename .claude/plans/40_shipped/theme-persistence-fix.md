# Fix Theme Persistence Across App Restarts {paintbrush.fill}
<!-- priority: 10 -->
<!-- tags: theme, settings -->

> Fixed theme resetting to default on app restart by storing raw string in AppStorage instead of enum.

## Problem
Selected theme resets to Ocean Dark after restarting the app.

## Root Cause
`@AppStorage` with `RawRepresentable` enum types (`AppTheme`) has inconsistent persistence behavior in SwiftUI — the stored format may not round-trip correctly across app launches.

## Fix
Changed all `@AppStorage("appTheme")` declarations from storing `AppTheme` directly to storing a raw `String`, with a computed property to convert back to the enum.

## Files Changed
- `CloudeApp.swift` — main app theme binding
- `SettingsView.swift` — settings theme reference
- `SettingsView+Theme.swift` — theme picker (where selection happens)
