# Refactor: Simplify Architecture + File Layout

## Goal
Make the Cloude iOS app easier to navigate and maintain without losing features.

## Constraints
- No feature loss, no behavior regressions.
- Small steps with frequent `xcodebuild` green checks.
- Prefer consistent naming with `+` suffix files grouped together.
- Reduce very large files; aim for ~200 LoC per file where practical.
- Avoid heavy abstractions / overengineering.

## Work Done (So Far)
- Connection event refactor: `ConnectionManager.events` (`PassthroughSubject<ConnectionEvent, Never>`) used by views via `.onReceive`.
- Added stale-socket guard in `ConnectionManager` to prevent duplicate receive loops.
- Git status correlation: queue requests since server result lacks a path; reset queue on disconnect.
- Flattened UI back into `Cloude/Cloude/UI/` (no feature folders) to keep `MainChatView+*.swift` etc grouped.
- File splits:
  - `ConnectionManager+API.swift` split into:
    - `ConnectionManager+MessageHandler.swift`
    - `ConnectionManager+API.swift` (public API surface)
  - `ConnectionManager.swift` split:
    - `ConnectionManager+ConversationOutput.swift` (moved `ConversationOutput` + `FileCache`)
  - `MainChatView.swift` split:
    - `MainChatView+EventHandling.swift`
    - `MainChatView+Modifiers.swift`
    - `MainChatView+Windows.swift`
  - `GlobalInputBar.swift` split:
    - `GlobalInputBar+ActionButton.swift`
    - `GlobalInputBar+Recording.swift`
- Updated plans folder naming convention:
  - `plans/00_backlog`, `plans/10_next`, `plans/20_active`, `plans/30_testing`, `plans/40_done`
- Skills output cleanup:
  - Video experiments moved under `.claude/skills/video/output/experiments/workbench`
  - Updated `.gitignore` and doc references.

## Next Steps
1. Split remaining large UI files:
   - `ConversationView+Components.swift`
   - `SettingsView.swift`
   - `ToolDetailSheet.swift`
   - `ChatView+MessageBubble.swift` (optional)
2. Split `ConnectionManager+MessageHandler.swift` by domain if still too large (Git/files/chat/heartbeat).
3. Keep `xcodebuild` green after each change.

## Verification
- Run:
  - `xcodebuild -project Cloude/Cloude.xcodeproj -scheme Cloude -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO`

