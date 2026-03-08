# Fix: Environment symbol picker not saving

## Problem
Changing an environment's symbol via the picker didn't persist. The `.onChange(of: env.symbol)` was attached to the `SymbolPickerSheet` inside the `.sheet` closure. When the picker set the symbol and immediately called `dismiss()`, the sheet tore down before `onChange` fired, so `onUpdate` was never called.

## Fix
Replaced `.onChange` inside the sheet with `onDismiss` on the `.sheet` modifier in `SettingsView+Environments.swift`.

## Files Changed
- `Cloude/UI/SettingsView+Environments.swift` - sheet onChange → onDismiss
