# App Folder Structure Round Three {square.grid.3x3.topleft.filled}
<!-- priority: 10 -->
<!-- tags: refactor, ui -->
> Move the iOS app from intermediate layer buckets to a feature-first structure with a tiny App root and strict Shared boundaries.

## Goal

Replace the current top-level `Views / Stores / Parsing / Utilities` emphasis with a cleaner product-oriented structure that matches how work actually happens in the app.

Target structure:

```text
Cloude/Cloude/
├── App/
├── Features/
└── Shared/
```

The intent is:
- `App/` stays tiny and only wires the app together
- `Features/` owns almost all product code
- `Shared/` contains only code with 2+ real feature consumers

## Why Round Three

Round two improved naming and removed the worst folder confusion, but the result still feels too layer-first.

The main problems left:
- `App/` still mixes entry wiring with feature logic
- `Parsing/` is technically valid but conceptually awkward at the top level
- `Views / Stores / Services / Utilities` still force the reader to ask what role a file plays before asking what product area it belongs to

The comparison point is the older `piasso` frontend structure, which felt cleaner because it grouped work by feature first and only kept a few truly global buckets.

## Top-Level Rules

### App

Only root composition code belongs here.

Allowed examples:
- `App.swift`
- app scene composition
- dependency injection and environment wiring
- deep-link entry points
- app bootstrap glue
- app-owned overlays that truly wrap the whole scene

Rule: `App/` should wire features together, not implement feature logic.

If deleting one feature requires deleting real behavior from `App/`, too much feature logic is still trapped there.

### Features

Product-specific code belongs here.

Expected feature folders:
- `Workspace/`
- `Conversation/`
- `Files/`
- `Git/`
- `Settings/`
- `Whiteboard/`
- `Plans/`
- `Memories/`
- `Window/`
- `Usage/`

Each feature may use subfolders like:
- `Views/`
- `Models/`
- `Store/`
- `Services/`
- `Utils/`
- `Parsing/`

Subfolders should exist only when needed.

It is acceptable for a small feature to contain only `Views/`.

If a tiny concept does not justify its own feature folder, it should stay inside its parent feature or move to `Shared/` if it is reused.

### Shared

Only cross-feature code with 2+ actual consumers belongs here.

Rule: nothing enters `Shared/` because it might be reused later.

Possible shared subfolders:
- `Views/`
- `Models/`
- `Store/`
- `Services/`
- `Utils/`
- `Theme/`

These are optional, not mandatory.

The important constraint is that `Shared/` stays earned and small.

## Critical Boundary Rules

1. Features must not import other features.
- If code is needed by multiple features, move it to `Shared/` or pass it through app-level composition.

2. `App/` should contain entry and composition only.
- Deep-link routing can enter through `App/`, but feature-specific handling should live in the feature.

3. Feature-local types stay local.
- Local models, stores, parsers, services, and utils should live inside the owning feature.

4. Shared code must be truly shared.
- Use the 2-consumer rule before moving anything into `Shared/`.

5. `Shared/` must not become a second global junk drawer.
- If a file only makes sense in one feature, move it back to that feature.

6. Parsing belongs with the owning feature unless it is truly cross-feature.
- Example: markdown parsing that only serves conversation rendering should live under `Features/Conversation/Parsing/`, not top-level `Parsing/`.

## Proposed First Mapping

### App

Likely to stay in `App/`:
- `App.swift`
- `App+MainContent.swift`
- `App+DebugOverlay.swift`
- the minimal app bootstrap and deep-link entry surface

Likely to move out of `App/` later:
- `App+WhiteboardHandling.swift` -> `Features/Whiteboard/`
- `App+Windows.swift` -> `Features/Window/` or `Features/Workspace/`
- `App+Navigation.swift` -> `Features/Workspace/`
- `App+Actions.swift` -> feature-owned once responsibilities are split

### Features

Initial likely mapping:
- `Features/Workspace/Views/` for `WorkspaceView*`
- `Features/Conversation/Views/` for `ConversationView*`, `MessageBubble*`, and conversation-owned markdown rendering
- `Features/Conversation/Parsing/` for `StreamingMarkdownParser*`, `StreamingBlock.swift`, `XMLNode*`, and likely `BashCommandParser*`
- `Features/Files/Views/` for `FileBrowserView*` and `FilePreviewView*`
- `Features/Git/Views/` for `GitChangesView*` and `GitDiffView*`
- `Features/Settings/Views/` for `SettingsView*`
- `Features/Whiteboard/Views/` and `Features/Whiteboard/Store/` for `WhiteboardSheet*` and `WhiteboardStore*`
- `Features/Plans/Views/` for `PlansSheet*`
- `Features/Memories/Views/` for `MemoriesSheet*`
- `Features/Window/Views/` and `Features/Window/Store/` for window editing and window state where appropriate
- `Features/Usage/Views/` for `UsageStatsSheet*`

### Shared

Likely shared candidates:
- `Shared/Theme/` for `Theme.swift`, `Theme+Palettes.swift`, `Colors.swift`
- `Shared/Services/` for truly app-wide services like `ConnectionManager*`, `EnvironmentConnection*`, `NotificationManager.swift`, `AudioRecorder.swift`
- `Shared/Views/` only for view primitives with 2+ real feature consumers, such as `ToolCallLabel*` if it remains cross-feature
- `Shared/Utils/` only for truly generic helpers like `AppLogger.swift`, `DateFormatters.swift`, `Keychain.swift`, `SafeSymbol.swift`

## Guidance For CLAUDE.md

Replace the round-two layer-first guidance with feature-first rules:

1. Top-level structure
- `App/` is root composition only
- `Features/` owns product-specific code
- `Shared/` owns only cross-feature code with 2+ real consumers

2. Feature boundary rule
- Features must not import other features
- Shared code is the only cross-feature home outside `App/`

3. Feature-local ownership rule
- Local views, models, stores, services, utils, and parsers stay inside their feature
- Small concepts should stay inside a parent feature instead of creating a tiny feature folder too early

4. Shared discipline rule
- Nothing goes into `Shared/` because it might be reused later
- Use the 2-consumer rule before moving code there

5. App rule
- `App/` wires features together and owns entry points
- `App/` should not accumulate feature logic

6. Parsing rule
- Parsing should live inside the owning feature unless it is truly cross-feature

## Migration Order

1. Commit the current round-two structure as a stable checkpoint
2. Create `Features/` and `Shared/`
3. Move the most obvious feature-owned buckets first:
- Workspace
- Conversation
- Files
- Git
- Settings
- Whiteboard
- Plans
- Memories
4. Move shared theme and cross-feature helpers into `Shared/`
5. Shrink `App/` so it only keeps composition and entry wiring
6. Update `CLAUDE.md` once the feature-first structure exists on disk
7. Build and smoke test after each feature cluster

## Risks

- `Shared/` becoming a second junk drawer
- wrong feature boundaries causing churn
- moving too many features in one pass and losing confidence
- letting `App/` keep too much feature logic after the move

Mitigation:
- move one or two obvious features at a time
- build after each cluster
- use the 2-consumer rule for `Shared/`
- keep `App/` small by default

## Verify

Outcome: the iOS target reads primarily by product area, not by technical layer, and future agents can locate code by feature first.

Test: inspect `/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/` and confirm `App/`, `Features/`, and `Shared/` exist, with at least the first moved features grouped under `Features/`. Run an iOS simulator build and verify bootstrap still succeeds.
