# Android Loading Animation {figure.walk}
<!-- priority: 15 -->
<!-- tags: android, ui, polish -->

> Custom mascot loading animation while Claude Code is running.

## Context

iOS has a custom frame-by-frame sprite animation (Sisyphus pushing a boulder) that plays while Claude Code is processing. 6 push frames followed by 8 retreat frames at 0.22s per frame. Android currently uses a basic Material progress indicator.

## Scope

- Design or port the Sisyphus sprite sheet for Android
- Implement frame-by-frame animation using `AnimatedImageVector` or manual frame cycling
- Replace the current `LinearProgressIndicator` in chat with the mascot animation
- Fall back to simple indicator if sprite assets not available

## Notes

Low priority, purely cosmetic polish.
