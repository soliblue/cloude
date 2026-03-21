# Dark Mode Default {moon.fill}
<!-- priority: 10 -->
<!-- tags: ui, theme -->

> Defaulted app theme to dark mode instead of following system setting.

Default the app theme to dark mode instead of system. Users can still override to system or light in Settings.

## Changes
- `CloudeApp.swift`: Changed `@AppStorage("appTheme")` default from `.system` to `.dark`
