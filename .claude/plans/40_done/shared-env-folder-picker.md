# Shared Environment + Folder Picker Component

The empty state and window edit sheet both have environment pickers and folder pickers but with different UI/UX and duplicated code. Unify into one reusable component.

## Goals
- Single `EnvironmentFolderPicker` view used in both places
- Same UX: env menu on top, divider, folder row below, all in one card
- Selecting an env auto-opens folder picker (like empty state does)

## Current State
- **Empty state** (`ConversationView+EmptyState.swift:96-167`): Combined card with env menu + divider + folder button. Selecting env auto-opens folder picker.
- **Window edit sheet** (`WindowEditSheet+Form.swift:73-111, 234-270`): Separate env picker (Menu) and folder button. Different sizing, no auto-open on env change.

## Approach
1. Extract `EnvironmentFolderPicker` into its own file
2. Parameters: environmentStore, connection, conversation, conversationStore, onFolderSelect callback
3. Replace both inline implementations with the shared component
4. Match empty state's combined card style (env + divider + folder in one rounded rect)

## Files
- New: `Cloude/Cloude/UI/EnvironmentFolderPicker.swift`
- Edit: `Cloude/Cloude/UI/ConversationView+EmptyState.swift`
- Edit: `Cloude/Cloude/UI/WindowEditSheet+Form.swift`
