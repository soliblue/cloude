# Fix: Environment symbol picker not saving {wrench}
<!-- priority: 10 -->
<!-- tags: settings, env -->

> Fixed environment symbol picker not persisting by using sheet onDismiss instead of onChange.

## Problem
Changing an environment's symbol via the picker didn't persist. The `.onChange(of: env.symbol)` was attached to the `SymbolPickerSheet` inside the `.sheet` closure. When the picker set the symbol and immediately called `dismiss()`, the sheet tore down before `onChange` fired, so `onUpdate` was never called.

## Fix
Replaced `.onChange` inside the sheet with `onDismiss` on the `.sheet` modifier in `SettingsView+Environments.swift`.

## Files Changed
- `Cloude/UI/SettingsView+Environments.swift` - sheet onChange → onDismiss
