# Sheet Theme Sync Fix

## Summary
Sheets (Settings, Theme Picker) didn't update colors when switching themes because `.preferredColorScheme` was only on the root CloudeApp view. Sheets are separate presentation contexts.

## Fix
Added `.preferredColorScheme(appTheme.colorScheme)` to both `SettingsView` and `ThemePickerView`.

## Files
- `SettingsView.swift` - Added `.preferredColorScheme`
- `SettingsView+Theme.swift` - Added `.preferredColorScheme`
