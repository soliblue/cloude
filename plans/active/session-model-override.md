# Session Model Override

## Problem
Currently, model selection only happens per-message via the send button menu. Users should be able to set a session-wide model preference that overrides the default model selection.

## Proposal
Make the logo at the top of the screen tappable to open a model selector sheet. Selected model becomes the session default and overrides the send button's default model selection.

## Design Questions
- **Visual indication**: How do we show which model is currently set for the session?
  - Badge on the logo?
  - Color tint?
  - Small text label below logo?
  - Show model name in header somewhere?

- **Persistence**: Should the override persist across app restarts or only for current session?

- **Relationship to send button menu**:
  - Should send button menu still allow one-off model changes?
  - Should send button show the session override model as selected by default?

- **Reset mechanism**: How does user return to default model selection behavior?
  - Explicit "Use Default" option in sheet?
  - Clear button in header?

## Implementation Notes
- Logo is in `StatusView` (Mac agent) and logo/pulse rendering in `MainChatView` (iOS)
- Model selection state needs to be tracked per conversation
- Would need to sync override preference between iOS app and Mac agent
- Send button menu logic is in `GlobalInputBar+Components.swift`

## Files
- `Cloude/Cloude/UI/MainChatView.swift` - Logo tap gesture + visual indicator
- `Cloude/Cloude/UI/GlobalInputBar+Components.swift` - Send button menu respects override
- `CloudeShared/Sources/CloudeShared/Models/Conversation.swift` - Add session model override field
