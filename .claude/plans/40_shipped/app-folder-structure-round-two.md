---
title: "App Folder Structure Round Two"
description: "Reorganize the iOS app into clear app, view, store, model, service, parsing, and utility boundaries."
created_at: 2026-04-01
tags: ["refactor", "ui"]
icon: folder.badge.gearshape
build: 122
---


# App Folder Structure Round Two
## Goal

Finish the naming cleanup by giving the iOS target a folder structure that is easy for future agents to classify correctly on first read.

Target structure:

```text
Cloude/Cloude/
├── App/
├── Views/
├── Stores/
├── Models/
├── Services/
├── Parsing/
└── Utilities/
```

## Target Rules

### App

Only `App.swift` and `App+*.swift` files.

Rule: if a file is not the app entry point or an extension of `App`, it does not belong in `App/`.

### Views

SwiftUI `View` types and owner-local split files only.

Rule: if a file defines something you would put in a SwiftUI `body`, it belongs in `Views/`.

Owner-local views should prefer the parent prefix when they have a single call site.

Examples already identified:
- `ConnectionStatusLogo.swift` should become `App+MainContent+SettingsButton.swift`
- `WorkspaceTitlePill.swift` should become `App+MainContent+WindowTitlePill.swift`
- `SisyphusLoadingView.swift` should become `MessageBubble+Loading.swift`
- `InlineToolPill.swift` should become `StreamingMarkdownView+InlineToolPill.swift`

Shared view primitives can stay standalone.

Confirmed shared example:
- `ToolCallLabel*`

### Stores

Observable mutable state only.

Candidates:
- `ConversationStore*`
- `EnvironmentStore.swift`
- `WindowManager.swift`
- `WhiteboardStore*`

Rule: if the type owns mutable app state over time, it belongs in `Stores/`.

### Models

Pure value types only.

Candidates:
- `Conversation.swift`
- `Conversation+ChatMessage.swift`
- `Conversation+ToolCall.swift`
- `Environment.swift`
- `MemoryDocument.swift`
- `ModelIdentity.swift`
- `WhiteboardElement.swift`
- `Window.swift`

Rule: models should be plain value types with no `SwiftUI` or observation imports.

### Services

Infrastructure and external/system integrations.

Candidates:
- `ConnectionManager*`
- `EnvironmentConnection*`
- `NotificationManager.swift`
- `AudioRecorder.swift`
- `OfflineCacheService.swift`
- `DebugMetrics.swift`
- `MemoryParser.swift`
- `MessageHistory.swift`

Rule: if it talks to network, files, audio, notifications, keychain, relay state, or another system boundary, it belongs in `Services/`.

### Parsing

Text and stream transformation code plus parser-owned intermediate types.

Candidates:
- `StreamingMarkdownParser*`
- `StreamingBlock.swift`
- `XMLNode*`
- `BashCommandParser*`

Rule: if the file turns raw text or structured input into intermediate content data consumed by views, it belongs in `Parsing/`.

This folder must not import SwiftUI.

### Utilities

Only truly generic helpers.

Candidates:
- `AppLogger.swift`
- `DateFormatters.swift`
- `Keychain.swift`
- `SafeSymbol.swift`
- `Theme.swift`
- `Theme+Palettes.swift`
- `Colors.swift`
- `View+AgenticTesting.swift`
- maybe `FileIconUtilities.swift` if it stays generic enough

Rule: if the file is domain-specific, it does not belong in `Utilities/`.

## Decisions

- Use `Views`, not `UI`
- Use `Stores`, not keeping observable state mixed into `Models`
- Keep a real `App/` folder instead of inventing a fake `Coordinators/` layer
- Use `Parsing/` for the markdown/XML/parser subsystem instead of dropping it into `Utilities/`
- Owner-local views should be colocated by prefix or folded into the owning file when there is only one call site

## Guidance For CLAUDE.md

Add or update project guidance so future agents do not drift:

1. Folder membership rules
- `App/` contains only `App.swift` and `App+*.swift`
- `Views/` contains only SwiftUI view files
- `Stores/` contains observable mutable state
- `Models/` contains pure value types
- `Services/` contains system and integration boundaries
- `Parsing/` contains parsers and parser-owned intermediate types
- `Utilities/` contains only truly generic helpers

2. Owner-local view rule
- If a view has a single call site, prefer naming it with its owner prefix or folding it into the owner file
- Shared view primitives can remain standalone

3. Parsing boundary rule
- Parsing files must not import SwiftUI
- Parser output types stay with the parser subsystem, not in `Models/`

4. Refactor hygiene
- Do not move and rename the same file in one commit when avoidable
- Do not mix structural moves with unrelated internal logic refactors
- Prefer moving obvious files first, then building, then doing narrower renames

## Proposed Phase Order

1. Create `App/`, `Views/`, `Stores/`, and `Parsing/`
2. Move `App.swift` and `App+*.swift` into `App/`
3. Rename `UI/` to `Views/`
4. Move observable state into `Stores/`
5. Move parser subsystem files into `Parsing/`
6. Move or rename owner-local views
7. Re-evaluate `Utilities/` so it stays strict and small
8. Build and smoke test after each cluster

## Verify

Outcome: the iOS target has an obvious folder structure with crisp membership rules, and future agents can classify files without inventing new buckets.

Test: inspect `/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/` and confirm the seven target folders exist with files grouped by the rules above. Run an iOS simulator build and smoke-test app launch, tab switching, settings, file preview, and one message send.
