---
title: "Dead Code Sweep (Periphery)"
description: "Run Periphery 3.6.0 against the iOS target to identify and delete all unused code across models, views, stores, and services."
created_at: 2026-04-19
tags: ["files", "agent"]
icon: trash
---

# Dead Code Sweep (Periphery) {trash}

Used Periphery 3.6.0 (Swift dead code scanner) against a fresh build index to identify unused code, then verified each candidate with grep before deleting. Periphery was scoped to the iOS target; several CloudeShared utilities it flagged were kept because they are consumed by the Mac agent target.

## What was deleted

**Conversation model**
- `Conversation.createdAt` property, Codable key, and init param
- `Conversation.symbolName` computed property
- `ToolCall.resultSummary` property, Codable key, and init param
- `ToolCall.isScript` computed property
- `WindowTab.label` computed property

**View dead fields and call sites**
- `ConversationView.onSelectConversation` + dead `refreshMissedResponse()` async function
- `ChatMessageList.onRefresh` field
- `EmptyConversationView.window` field
- `BubbleInteractionModifier.hasInteractiveWidgets` field and its computed property
- `WindowEditSheet.onNewConversation` field + closure block in `WorkspaceView+Lifecycle.swift`
- `EnvironmentCard.isActive` field
- `SlashCommand.description` field, init param, removed from `fromSkill` (2 places) and all 5 `builtInCommands` entries

**WorkspaceView+State.swift**
- 10 unused get/nonmutating-set passthrough properties removed: `editingWindow`, `inputText`, `attachedImages`, `attachedFiles`, `drafts`, `gitBranches`, `gitStats`, `pendingGitChecks`, `showConversationSearch`, `refreshingSessionIds`

**Services / events**
- `ConnectionEvent.missedResponse` enum case (zero consumers)
- `handleToolResult(summary:)` parameter removed from signature, callsite, and assignment

**Ongoing refactor (bundled)**
Model file moves and new type extractions already in progress were bundled into the same commit: `ChatMessageKind.swift`, `EffortLevel.swift`, `ModelIdentity.swift` (moved to Conversation feature), `ConnectionPhase.swift`, `StreamPhase.swift`, `ConversationOutput.swift`, `PendingChunk.swift`, and others. Deleted `PillStyles.swift`, `AudioRecorder.swift` (renamed), `MessageHistory.swift` (moved), `ConnectionManager+ConversationOutput.swift` (split out).

## What was kept (Periphery false positives)

- `Image.safeSymbol` extension - used in `ConversationRowContent.swift`
- `FileIconUtilities.swift` free functions - used by 6 files
- `NetworkHelper`, `ToolInputExtractor`, `String.expandingTildeInPath`, `String.appendingPathComponent(_:)` - used by Mac agent target
