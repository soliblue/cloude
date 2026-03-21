# Conversation Name History {clock.arrow.trianglehead.counterclockwise.rotate.90}
<!-- priority: 2 -->
<!-- tags: ui, search, metadata -->

> Track previous conversation names so renamed conversations are still findable.

## Problem

Conversations get renamed as topics shift (auto-rename fires after first message, user renames manually, agent calls `mcp__ios__rename`). Once renamed, the old name is lost. If you remember a conversation by its earlier name, search won't find it.

## Design Decision

Old names are NOT shown in the main UI. They only surface in search results. When a search query matches a previous name, show it as secondary text under the current name (like how message matches already work).

No initial random name in history (e.g. "Spark", "Nova"). Only names set by auto-rename or user rename get tracked.

## Current State

- `Conversation` model has `name: String`, no history
- `renameConversation()` in `ConversationStore+Operations.swift:47` just overwrites `name`
- Search in `MainChatView+SearchSheet.swift:13` filters on `name`, `workingDirectory`, and message text
- Search results in `MainChatView+SearchSheet+Components.swift:5` show a message snippet when the match came from message content (not name/directory)

## Implementation

### 1. `Cloude/Cloude/Models/Conversation.swift`

**Add `previousNames` field** after `name` (line 6):
```swift
var previousNames: [String] = []
```

Non-optional, defaults to empty. Existing JSON files without this field decode cleanly via the custom decoder.

**Update `init(from decoder:)`** (after line 66):
```swift
previousNames = try container.decodeIfPresent([String].self, forKey: .previousNames) ?? []
```

**Update `CodingKeys`** (line 79):
```swift
case id, name, previousNames, symbol, sessionId, workingDirectory, createdAt, lastMessageAt, messages, pendingMessages, pendingFork, defaultEffort, defaultModel, environmentId
```

**Update `init()`** (after line 53, inside the initializer):
```swift
self.previousNames = []
```

### 2. `Cloude/Cloude/Models/ConversationStore+Operations.swift`

**Update `renameConversation()`** (line 47-48) to append old name before overwriting:
```swift
func renameConversation(_ conversation: Conversation, to name: String) {
    mutate(conversation.id) {
        let oldName = $0.name
        $0.name = name
        if !oldName.isEmpty && oldName.lowercased() != name.lowercased() && !Conversation.randomNames.contains(oldName) {
            $0.previousNames.removeAll { $0.lowercased() == oldName.lowercased() }
            $0.previousNames.append(oldName)
            if $0.previousNames.count > 20 {
                $0.previousNames.removeFirst($0.previousNames.count - 20)
            }
        }
    }
}
```

Key rules:
- Don't store random default names ("Spark", "Nova", etc.) in history
- Dedupe case-insensitively before appending (handles toggling between names)
- Cap at 20 entries, drop oldest first

**Update `duplicateConversation()`** (line 72) to NOT copy `previousNames` to the fork (clean slate).

### 3. `Cloude/Cloude/UI/MainChatView+SearchSheet.swift`

**Update `results` filter** (line 18-22) to include previousNames:
```swift
return all.filter { conv in
    conv.name.lowercased().contains(query) ||
    conv.previousNames.contains { $0.lowercased().contains(query) } ||
    (conv.workingDirectory?.lowercased().contains(query) ?? false) ||
    conv.messages.contains { $0.text.lowercased().contains(query) }
}
```

### 4. `Cloude/Cloude/UI/MainChatView+SearchSheet+Components.swift`

**Update `conversationRow()`** (after line 27, before the message match block) to show matched previous name:
```swift
if !searchText.isEmpty, let oldName = matchedPreviousName(conv) {
    Text("was: \(oldName)")
        .font(.caption2)
        .foregroundColor(.secondary)
        .italic()
        .lineLimit(1)
        .padding(.top, 2)
}
```

Only show this when the match came from a previous name (not current name or directory).

**Update `firstMessageMatch()`** (line 47) to also skip when previousNames matched:
```swift
func firstMessageMatch(_ conv: Conversation) -> String? {
    let query = searchText.lowercased()
    if conv.name.lowercased().contains(query) ||
       conv.previousNames.contains(where: { $0.lowercased().contains(query) }) ||
       (conv.workingDirectory?.lowercased().contains(query) ?? false) {
        return nil
    }
    // ... rest unchanged
}
```

**Add `matchedPreviousName()`**:
```swift
func matchedPreviousName(_ conv: Conversation) -> String? {
    let query = searchText.lowercased()
    if conv.name.lowercased().contains(query) { return nil }
    return conv.previousNames.first { $0.lowercased().contains(query) }
}
```

Only returns a match when the current name does NOT match (so we're explaining why this result appeared).

## Files Changed (4)

| File | What |
|------|------|
| `Cloude/Cloude/Models/Conversation.swift` | Add `previousNames: [String]`, decode with fallback |
| `Cloude/Cloude/Models/ConversationStore+Operations.swift` | Append old name on rename, cap at 20, skip random names |
| `Cloude/Cloude/UI/MainChatView+SearchSheet.swift` | Include `previousNames` in search filter |
| `Cloude/Cloude/UI/MainChatView+SearchSheet+Components.swift` | Show "was: OldName" when previous name matched |

## Risk

- **Zero migration needed**. `decodeIfPresent` with `?? []` fallback means existing conversation JSON files decode without changes.
- **No server/relay changes**. This is iOS-only. Names are renamed on the iOS side via events, history is tracked locally.
- **No UI clutter**. Previous names never appear outside search results.
- **Bounded**. 20-entry cap prevents bloat from frequent renames.
