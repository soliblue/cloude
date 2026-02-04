# Conversation Architecture Refactor

## Background

### The Problem

The current architecture has two parallel systems for chat:

1. **Regular chats** — `ProjectChatView` → `ProjectStore` → `Project` → `Conversation`
2. **Heartbeat** — `HeartbeatChatView` → `HeartbeatStore` → `HeartbeatConversation`

These share `ProjectChatMessageList` for rendering messages, but diverge on everything else:
- Different data models
- Different stores
- Different persistence
- Different input handling
- Different question handling (questions don't work in heartbeat!)

This means every feature added to chat needs to be implemented twice. The `cloude ask` question UI is a concrete example — it works in regular windows but not in heartbeat because heartbeat doesn't pass `projectStore` to the shared component.

### The Root Cause

Two unnecessary abstractions:

1. **Project as a separate entity** — Projects only provide `rootDirectory` and group conversations. But every `Conversation` already has `workingDirectory`. Projects are redundant.

2. **Heartbeat as a special system** — Heartbeat is just a conversation with a fixed ID and different window chrome (header with trigger button, always-open behavior). The chat content is identical.

### The Solution

Flatten the architecture:

- **One data model**: `Conversation` (already exists, no changes needed)
- **One store**: `ConversationStore` (renamed from `ProjectStore`)
- **One chat component**: `ConversationView` (renders any conversation)
- **Two window types**: `Window` (closeable, tabs) and `Heartbeat` (always-open, cron trigger)

"Projects" become a UI grouping — conversations with the same `workingDirectory` are displayed together. No `Project` model needed.

---

## Current Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         Data Layer                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ProjectStore                      HeartbeatStore                │
│  ├── projects: [Project]           ├── conversation              │
│  │     └── conversations           ├── unreadCount               │
│  ├── currentProject                ├── intervalMinutes           │
│  ├── currentConversation           └── lastRun                   │
│  └── pendingQuestion                                             │
│                                                                  │
│  Project                           HeartbeatConversation         │
│  ├── id                            ├── messages                  │
│  ├── name                          └── pendingMessages           │
│  ├── rootDirectory                                               │
│  └── conversations: [Conversation]                               │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                          UI Layer                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  MainChatView                                                    │
│  ├── windowContent()               ├── heartbeatWindowContent()  │
│  │     │                           │     │                       │
│  │     ▼                           │     ▼                       │
│  │   ProjectChatView               │   HeartbeatChatView         │
│  │   ├── ProjectChatHeader         │   ├── (header in parent)    │
│  │   └── ProjectChatMessageList    │   └── ProjectChatMessageList│
│  │         ├── messages            │         ├── messages        │
│  │         ├── streaming           │         ├── streaming       │
│  │         ├── QuestionView ✓      │         ├── QuestionView ✗  │
│  │         └── (needs projectStore)│         └── (no projectStore)
│  │                                 │                             │
└─────────────────────────────────────────────────────────────────┘
```

**Problems:**
- `QuestionView` only works because it reads `projectStore?.pendingQuestion`
- Heartbeat doesn't pass `projectStore`, so questions silently fail
- Two code paths for everything: persistence, sending messages, handling completion
- Adding features requires changes in two places

---

## Target Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         Data Layer                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ConversationStore                                               │
│  ├── conversations: [Conversation]                               │
│  ├── currentConversation                                         │
│  ├── pendingQuestion                                             │
│  └── heartbeatConfig: HeartbeatConfig                            │
│                                                                  │
│  Conversation (unchanged)          HeartbeatConfig (new, simple) │
│  ├── id                            ├── unreadCount               │
│  ├── name                          ├── intervalMinutes           │
│  ├── symbol                        └── lastRun                   │
│  ├── sessionId                                                   │
│  ├── workingDirectory  ◄── used for grouping in UI               │
│  ├── messages                                                    │
│  └── pendingMessages                                             │
│                                                                  │
│  Heartbeat conversation:                                         │
│  ├── id: Heartbeat.conversationId (fixed UUID)                   │
│  ├── sessionId: "heartbeat" (fixed)                              │
│  ├── workingDirectory: set by Mac agent                          │
│  └── (everything else same as regular conversation)              │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                          UI Layer                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  MainChatView                                                    │
│  ├── Window                        ├── Heartbeat                 │
│  │     ├── WindowHeader            │     ├── HeartbeatHeader     │
│  │     │   ├── tabs                │     │   ├── trigger button  │
│  │     │   ├── name                │     │   ├── interval picker │
│  │     │   └── close               │     │   └── unread count    │
│  │     │                           │     │                       │
│  │     └── ConversationView ◄──────┴─────┴── ConversationView    │
│  │           ├── messages                      (SAME COMPONENT)  │
│  │           ├── streaming                                       │
│  │           ├── tool calls                                      │
│  │           └── QuestionView ✓ (works for both!)                │
│  │                                                               │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                    Conversation List UI                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Grouped by workingDirectory:                                    │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │ 📁 cloude                       ~/Desktop/CODING/cloude     ││
│  │   💬 Bug Fix                                                ││
│  │   💬 Feature                                                ││
│  │   💬 Demo Session                                           ││
│  │   (heartbeat hidden — same workingDirectory but filtered)   ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                  │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │ 📁 other-project                          ~/other-project   ││
│  │   💬 Refactor                                               ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                  │
│  Grouping is derived: conversations.grouped(by: \.workingDirectory)
│  No Project model needed                                         │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## File Changes

### Files to DELETE

| File | Reason |
|------|--------|
| `Models/HeartbeatStore.swift` | Heartbeat becomes a regular Conversation |
| `Models/Project.swift` | Projects derived from workingDirectory |
| `UI/HeartbeatChatView.swift` | Use shared ConversationView |
| `UI/HeartbeatSheet.swift` | No longer needed |

### Files to RENAME/REFACTOR

| Current | New | Changes |
|---------|-----|---------|
| `Models/ProjectStore.swift` | `Models/ConversationStore.swift` | Store flat `[Conversation]` instead of `[Project]` with nested conversations |
| `Models/ProjectStore+Conversation.swift` | Merge into `ConversationStore.swift` | Conversation management methods |
| `UI/ProjectChatView+Components.swift` | `UI/ConversationView.swift` | Remove project dependencies, take `conversationId` + `store` |
| `UI/ProjectChatView.swift` | `UI/Window.swift` | Use ConversationView inside, keep window chrome |

### Files to CREATE

| File | Purpose |
|------|---------|
| `UI/WindowHeader.swift` | Extracted from ProjectChatView — tabs, name, close button |
| `UI/HeartbeatHeader.swift` | Extracted from MainChatView — trigger button, interval picker, unread count |
| `Models/HeartbeatConfig.swift` | Simple struct for heartbeat-specific settings (not a store) |

### Files to EDIT

| File | Changes |
|------|---------|
| `UI/MainChatView.swift` | Use Window and Heartbeat components, both with ConversationView |
| `App/CloudeApp.swift` | Use ConversationStore instead of ProjectStore + HeartbeatStore |
| `UI/HeartbeatButton.swift` | Use ConversationStore for heartbeat conversation |
| `Services/ConnectionManager.swift` | Route all messages through ConversationStore |
| `UI/GlobalInputBar.swift` | Update to work with ConversationStore |

---

## Implementation Steps

### Phase 1: Create ConversationStore

1. Create `ConversationStore.swift` with flat conversation list
2. Add grouping computed property: `conversationsByDirectory`
3. Add heartbeat helpers: `heartbeatConversation`, `isHeartbeat(id:)`
4. Add `HeartbeatConfig` for interval/unread tracking
5. Migrate persistence from nested project structure to flat list

### Phase 2: Create ConversationView

1. Rename `ProjectChatMessageList` to `ConversationView`
2. Change inputs from project/conversation to just `conversationId` + `store`
3. Look up conversation from store internally
4. Make `QuestionView` work by checking `store.pendingQuestion` with conversationId
5. Add `onSendMessage` that uses conversation's own sessionId/workingDirectory

### Phase 3: Refactor Window

1. Rename `ProjectChatView` to `Window`
2. Extract header to `WindowHeader.swift`
3. Use `ConversationView` for chat content
4. Update to use `ConversationStore`

### Phase 4: Refactor Heartbeat

1. Delete `HeartbeatChatView` and `HeartbeatSheet`
2. Create `HeartbeatHeader.swift` (trigger, interval, unread)
3. Update heartbeat window in `MainChatView` to use `HeartbeatHeader` + `ConversationView`
4. Ensure heartbeat conversation created on app launch with fixed ID

### Phase 5: Update App Wiring

1. Update `CloudeApp.swift` to use single `ConversationStore`
2. Update `ConnectionManager` message routing
3. Update conversation list UI to group by `workingDirectory`
4. Delete `HeartbeatStore`, `Project.swift`

### Phase 6: Migration

1. Write migration code to convert existing data:
   - Flatten `[Project] → [Conversation]`
   - Preserve workingDirectory from project.rootDirectory
   - Migrate heartbeat messages to new conversation
2. Test with existing user data

---

## Edge Cases to Handle

### Heartbeat Working Directory

Heartbeat's `workingDirectory` is set by the Mac agent via `HeartbeatService.projectDirectory`. On first launch, it may be nil. Options:

1. Leave nil until first heartbeat run (Mac agent sends it)
2. Default to app's home project directory

**Decision:** Option 1 — heartbeat conversation starts with nil workingDirectory, Mac agent sets it on first run.

### Conversation List Filtering

Heartbeat should not appear in the conversation list. Filter by:

```swift
var listableConversations: [Conversation] {
    conversations.filter { $0.id != Heartbeat.conversationId }
}
```

### Question Routing

Questions arrive with `conversationId`. The flow:

1. Mac agent intercepts `cloude ask`, extracts conversationId from tool call context
2. Broadcasts `.question(questions:, conversationId:)`
3. iOS sets `store.pendingQuestion = PendingQuestion(conversationId, questions)`
4. `ConversationView` checks if `store.pendingQuestion?.conversationId == self.conversationId`
5. If match, renders `QuestionView`
6. On submit, sends answer via `connection.sendChat(...)` using conversation's sessionId

This works for both regular and heartbeat conversations — no special handling needed.

### Persistence Migration

Current structure:
```
UserDefaults["saved_projects"] = [Project]
  └── conversations: [Conversation]

Separate file for heartbeat
```

New structure:
```
UserDefaults["saved_conversations"] = [Conversation]
  └── each has workingDirectory (was project.rootDirectory)

HeartbeatConfig stored separately (just settings, not messages)
```

Migration:
```swift
func migrate() {
    // Load old format
    let oldProjects = loadOldProjects()

    // Flatten
    var allConversations: [Conversation] = []
    for project in oldProjects {
        for var conv in project.conversations {
            conv.workingDirectory = conv.workingDirectory ?? project.rootDirectory
            allConversations.append(conv)
        }
    }

    // Add heartbeat if exists
    if let heartbeat = loadOldHeartbeat() {
        let conv = Conversation(
            id: Heartbeat.conversationId,
            sessionId: "heartbeat",
            workingDirectory: heartbeat.workingDirectory,
            messages: heartbeat.messages
        )
        allConversations.append(conv)
    }

    // Save new format
    save(allConversations)
}
```

---

## Benefits

1. **Questions work in heartbeat** — the original motivation
2. **One code path** — features added once work everywhere
3. **Simpler mental model** — conversations are the only entity
4. **Less code** — delete HeartbeatStore, HeartbeatChatView, HeartbeatSheet, Project
5. **Easier testing** — one component to test, not two parallel systems
6. **Future-proof** — easy to add new window chrome types without duplicating chat logic

---

## Risks

1. **Data migration** — need to carefully migrate existing user data
2. **Scope creep** — tempting to refactor more while we're at it
3. **Regression risk** — touching core chat components

### Mitigation

- Write migration with rollback capability
- Keep refactor focused on the architecture change only
- Test thoroughly with existing conversations before deploying

---

## Open Questions

1. **Should heartbeat appear in conversation list when filtered by its workingDirectory?**
   - Current thinking: No, always hide it. It has its own dedicated window.

2. **What happens if user deletes all conversations for a workingDirectory?**
   - The "project" disappears from the grouped list. That's fine — it was just a grouping.

3. **Should we keep project names, or derive them from directory path?**
   - Current thinking: Derive from path (last component). Simpler, no separate naming needed.
