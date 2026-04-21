# Accessibility targeting (v2)

Prefer deep links over UI tapping. The v2 app hasn't been instrumented with stable `accessibilityIdentifier` values yet, so UI-driven tests rely on visual capture.

When adding coverage that *must* tap (e.g. attachment picker, tool pill sheet), add an explicit `.accessibilityIdentifier("cloude.<feature>.<element>")` on the view and document it here.

| id | location |
|---|---|
| (none yet) | — |
