# Smart Autocomplete {text.badge.star}
<!-- priority: 7 -->
<!-- tags: input, agent, relay, ui -->

> AI-powered suggestions that improve over time, stored server-side per environment.

## How It Works

### The file
`.cloude/suggestions.md` on each server. One suggestion per line, HTML comment with timestamp at top:
```
<!-- lastUpdated: 2026-03-21T14:30:00Z -->
check the build status
run the tests
what do you think?
show me the diff
deploy to testflight
```

The timestamp is agent-only (not sent to iOS). Used to filter which conversation messages to analyze when improving.

### The flow
1. User opens `/autocomplete` on phone
2. Phone sends `getAutocomplete` to active env
3. Agent reads `.cloude/suggestions.md`, sends lines back immediately (excluding the timestamp comment)
4. Phone caches per-env in UserDefaults, shows the sheet
5. Agent kicks off background task: reads conversation messages since `lastUpdated`, runs Sonnet to improve/merge/add suggestions, writes file back with new timestamp
6. Next time user opens `/autocomplete`, they get the improved version

### What Sonnet does (background improvement)
- Analyzes messages sent since last update
- Merges similar suggestions ("check build" + "check the build status" = keep the better one)
- Adds new suggestions based on patterns (if user keeps asking about deploys, add deploy-related suggestions)
- Removes stale/unused ones
- Keeps total under 500 entries
- Does NOT touch the timestamp comment format

### What it doesn't do
- No per-keystroke requests (latency would kill it)
- No auto-trigger after every response (too aggressive)
- No complex sync protocol (just fetch-on-open, like plans/memories)

## Architecture: Server-side, per-environment (like plans/memories)

**Why server-side:**
- Agent can read/write directly as a file, no MCP tools needed
- Sonnet improvement is trivial: read file + recent messages, pipe to `claude --model sonnet --print`, write back
- Survives app reinstalls
- Same pattern as plans/memories, no new architecture

**Per-environment:** Each server maintains its own file. iOS caches per-env, searches across ALL cached envs for inline suggestions. Different servers naturally build different suggestion sets (coding on Mac, server ops on medina).

### Data flow
```
Mac (home):    .cloude/suggestions.md     (up to 500 lines)
Medina:        .cloude/suggestions.md     (up to 500 lines)
               ↕ read/write by agent handler

iOS app:       UserDefaults["suggestions_{envId}"]  (cached per env)
               ↕ fetches on /autocomplete open
               → inline suggestions search ALL env caches combined
```

## Implementation

### Layer 1: Shared Models (CloudeShared)

**`ClientMessage.swift`** - add 3 cases after `deletePlan`:
```swift
case getAutocomplete
case saveAutocompleteEntry(text: String)
case deleteAutocompleteEntry(text: String)
```

**`ClientMessage+Encoding.swift`** - add encoding for the 3 new cases:
- `getAutocomplete` -> `{ type: "get_autocomplete" }`
- `saveAutocompleteEntry` -> `{ type: "save_autocomplete_entry", text: "..." }`
- `deleteAutocompleteEntry` -> `{ type: "delete_autocomplete_entry", text: "..." }`

**`ServerMessage.swift`** - add 1 case after `planDeleted`:
```swift
case autocompleteData(entries: [String])
```

**`ServerMessage+Decoding.swift`** / **`ServerMessage+DecodingExt.swift`** - decode `autocomplete_data` type:
- Read `entries` as `[String]`

**`ServerMessage+Encoding.swift`** / **`ServerMessage+EncodingExt.swift`** - encode (for Mac agent):
- Write `{ type: "autocomplete_data", entries: [...] }`

### Layer 2: Linux Relay

**`handlers-suggestions.js`** (NEW) - mirrors pattern from `handlers-plans.js`:
```javascript
export function handleGetAutocomplete(workingDirectory, ws, sendTo) {
  // read .cloude/suggestions.md
  // parse: skip <!-- lastUpdated: ... --> line, split remaining by \n
  // sendTo(ws, { type: 'autocomplete_data', entries })
  // then kick off background improvement (spawn claude --model sonnet --print)
}

export function handleSaveAutocompleteEntry(text, workingDirectory, ws, sendTo) {
  // read file, dedup (case-insensitive), prepend entry, write back
  // sendTo(ws, { type: 'autocomplete_data', entries }) with full updated list
}

export function handleDeleteAutocompleteEntry(text, workingDirectory, ws, sendTo) {
  // read file, remove matching line, write back
  // sendTo(ws, { type: 'autocomplete_data', entries }) with full updated list
}
```

Background improvement function (called after `handleGetAutocomplete` responds):
```javascript
async function improveAutocomplete(workingDirectory) {
  // 1. read .cloude/suggestions.md, extract lastUpdated timestamp
  // 2. find conversation JSONL files modified since lastUpdated
  //    (from ~/.claude/projects/*/conversations/*.jsonl)
  // 3. extract user messages from those files
  // 4. if no new messages, skip
  // 5. spawn: claude --model sonnet --print "Given these recent user messages
  //    and current suggestions, output an improved suggestions list..."
  // 6. write result back to .cloude/suggestions.md with new timestamp
}
```

**`handlers.js`** - add 3 cases in the switch after `delete_plan`:
```javascript
case 'get_autocomplete':
  handleGetAutocomplete(msg.workingDirectory, ws, sendTo)
  break
case 'save_autocomplete_entry':
  handleSaveAutocompleteEntry(msg.text, msg.workingDirectory, ws, sendTo)
  break
case 'delete_autocomplete_entry':
  handleDeleteAutocompleteEntry(msg.text, msg.workingDirectory, ws, sendTo)
  break
```

### Layer 3: Mac Agent

**`Cloude Agent/Services/SuggestionsService.swift`** (NEW) - same logic as relay but in Swift:
- `static func load(workingDirectory: String) -> [String]` - read file, return entries
- `static func save(entry: String, workingDirectory: String)` - dedup + prepend
- `static func delete(entry: String, workingDirectory: String)` - remove line
- `static func improve(workingDirectory: String)` - background Process spawning `claude --model sonnet --print`

**`Cloude Agent/App/AppDelegate+MessageHandling.swift`** - add 3 cases after `.deletePlan`:
```swift
case .getAutocomplete:
    let entries = SuggestionsService.load(workingDirectory: wd)
    server.sendMessage(.autocompleteData(entries: entries), to: connection)
    SuggestionsService.improve(workingDirectory: wd) // fire-and-forget

case .saveAutocompleteEntry(let text):
    SuggestionsService.save(entry: text, workingDirectory: wd)
    let entries = SuggestionsService.load(workingDirectory: wd)
    server.sendMessage(.autocompleteData(entries: entries), to: connection)

case .deleteAutocompleteEntry(let text):
    SuggestionsService.delete(entry: text, workingDirectory: wd)
    let entries = SuggestionsService.load(workingDirectory: wd)
    server.sendMessage(.autocompleteData(entries: entries), to: connection)
```

### Layer 4: iOS App

**`ConnectionEvent.swift`** - add after `planDeleted`:
```swift
case autocompleteData([String])
```

**`EnvironmentConnection+MessageHandler.swift`** - add in the switch after `.planDeleted`:
```swift
case .autocompleteData(let entries): mgr.events.send(.autocompleteData(entries))
```

**`MessageHistory.swift`** - refactor from global to per-env. Also serves as the local cache (no OfflineCacheService needed):
```swift
struct MessageHistory {
    private static let maxEntries = 500
    private static let maxLength = 100

    private static func key(for envId: UUID?) -> String {
        envId.map { "suggestions_\($0.uuidString)" } ?? "suggestions_default"
    }

    static func save(_ text: String, environmentId: UUID? = nil) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed.count > maxLength || trimmed.hasPrefix("/") { return false }
        var history = load(environmentId: environmentId)
        history.removeAll { $0.lowercased() == trimmed.lowercased() }
        history.insert(trimmed, at: 0)
        if history.count > maxEntries { history = Array(history.prefix(maxEntries)) }
        UserDefaults.standard.set(history, forKey: key(for: environmentId))
        return true
    }

    static func load(environmentId: UUID? = nil) -> [String] {
        UserDefaults.standard.stringArray(forKey: key(for: environmentId)) ?? []
    }

    static func replaceAll(_ entries: [String], environmentId: UUID?) {
        UserDefaults.standard.set(entries, forKey: key(for: environmentId))
    }

    static func delete(_ text: String, environmentId: UUID? = nil) {
        var history = load(environmentId: environmentId)
        history.removeAll { $0.lowercased() == text.lowercased() }
        UserDefaults.standard.set(history, forKey: key(for: environmentId))
    }

    static func loadAll(environmentIds: [UUID]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for id in environmentIds {
            for entry in load(environmentId: id) {
                if seen.insert(entry.lowercased()).inserted { result.append(entry) }
            }
        }
        return result
    }

    static func suggestions(for query: String, environmentIds: [UUID]) -> [String] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty || q.hasPrefix("/") || q.hasPrefix("@") { return [] }
        let all = loadAll(environmentIds: environmentIds)
        let prefix = all.filter { $0.lowercased().hasPrefix(q) && $0.lowercased() != q }
        let contains = all.filter { !$0.lowercased().hasPrefix(q) && $0.lowercased().contains(q) }
        return prefix + contains
    }
}
```

**`ConnectionManager+API.swift`** - add convenience methods:
```swift
func getAutocomplete(environmentId: UUID? = nil) {
    connectionForSend(environmentId: environmentId)?.send(.getAutocomplete)
}

func saveAutocompleteEntry(_ text: String, environmentId: UUID? = nil) {
    connectionForSend(environmentId: environmentId)?.send(.saveAutocompleteEntry(text: text))
}

func deleteAutocompleteEntry(_ text: String, environmentId: UUID? = nil) {
    connectionForSend(environmentId: environmentId)?.send(.deleteAutocompleteEntry(text: text))
}
```

**`SlashCommand.swift`** - add to `builtInCommands` array:
```swift
SlashCommand(name: "autocomplete", description: "Manage suggestions", icon: "text.badge.star"),
```

**`CloudeApp.swift`** - add state:
```swift
@State var showAutocomplete = false
@State var autocompleteEntries: [String] = []
@State var isLoadingAutocomplete = false
@State var autocompleteFromCache = false
```

**`CloudeApp+Actions.swift`** - add `openAutocomplete()`. Uses `MessageHistory` as the cache (no `OfflineCacheService`):
```swift
func openAutocomplete() {
    let envId = environmentStore.activeEnvironmentId
    let cached = MessageHistory.load(environmentId: envId)
    autocompleteEntries = cached
    autocompleteFromCache = !cached.isEmpty
    isLoadingAutocomplete = connection.isAuthenticated
    if connection.isAuthenticated {
        connection.getAutocomplete(environmentId: envId)
    }
    showAutocomplete = true
}
```

**`CloudeApp+EventHandling.swift`** - add case after `.planDeleted`:
```swift
case .autocompleteData(let entries):
    autocompleteEntries = entries
    autocompleteFromCache = false
    isLoadingAutocomplete = false
    MessageHistory.replaceAll(entries, environmentId: environmentStore.activeEnvironmentId)
```

**`MainChatView.swift`** - add callback:
```swift
var onShowAutocomplete: (() -> Void)?
```

**`CloudeApp+MainContent.swift`** - wire it up:
```swift
onShowAutocomplete: { openAutocomplete() },
```

**`MainChatView+Messaging.swift`** - add handler after `/whiteboard`:
```swift
if trimmedLower == "/autocomplete" {
    onShowAutocomplete?()
    return
}
```

Also update `sendMessage()` to save per-env:
```swift
// change: MessageHistory.save(text)
// to:
let envId = currentConversation?.environmentId ?? environmentStore.activeEnvironmentId
if MessageHistory.save(text, environmentId: envId) {
    connection.saveAutocompleteEntry(text, environmentId: envId)
}
```

**`MainChatView+AutocompleteSheet.swift`** (NEW) - the sheet UI:
- NavigationStack + `.toolbar` pattern (like plans/memories sheets)
- `xmark` dismiss in `.topBarTrailing`
- Search bar at top
- List of entries, each row: text + trash button
- Tap row -> fills input bar, dismisses sheet
- Trash button -> deletes locally + sends `deleteAutocompleteEntry` to server
- "From cache" badge when `autocompleteFromCache` is true
- Loading spinner when `isLoadingAutocomplete`

### Layer 5: Inline Suggestions Update

**`GlobalInputBar+Suggestions.swift`** - update `historySuggestions` computed property to use per-env `MessageHistory.suggestions(for:environmentIds:)` instead of the current global `MessageHistory.suggestions(for:)`.

## Files Summary

### New (3)
| File | What |
|------|------|
| `linux-relay/handlers-suggestions.js` | Read/write/delete/improve `.cloude/suggestions.md` |
| `Cloude Agent/Services/SuggestionsService.swift` | Same as relay but Swift |
| `Cloude/UI/MainChatView+AutocompleteSheet.swift` | Sheet with search, tap-to-fill, delete |

### Modified (19)
| File | What |
|------|------|
| `CloudeShared/Messages/ClientMessage.swift` | 3 new cases |
| `CloudeShared/Messages/ClientMessage+Encoding.swift` | Encode 3 new cases |
| `CloudeShared/Messages/ServerMessage.swift` | 1 new case |
| `CloudeShared/Messages/ServerMessage+Decoding.swift` | Decode `autocomplete_data` |
| `CloudeShared/Messages/ServerMessage+Encoding.swift` | Encode `autocomplete_data` |
| `Cloude/Services/ConnectionEvent.swift` | `autocompleteData` case |
| `Cloude/Services/EnvironmentConnection+MessageHandler.swift` | Route `autocompleteData` |
| `Cloude/Services/ConnectionManager+API.swift` | 3 convenience methods |
| `Cloude/Services/MessageHistory.swift` | Refactor to per-env (also serves as cache, no OfflineCacheService needed) |
| `Cloude/UI/SlashCommand.swift` | Add `autocomplete` command |
| `Cloude/UI/MainChatView.swift` | Add `onShowAutocomplete` callback |
| `Cloude/UI/MainChatView+Messaging.swift` | Handle `/autocomplete` + per-env save |
| `Cloude/UI/GlobalInputBar+Suggestions.swift` | Use per-env suggestions |
| `Cloude/App/CloudeApp.swift` | 4 state vars |
| `Cloude/App/CloudeApp+Actions.swift` | `openAutocomplete()` |
| `Cloude/App/CloudeApp+MainContent.swift` | Wire `onShowAutocomplete` |
| `Cloude/App/CloudeApp+EventHandling.swift` | Handle `autocompleteData` event |
| `Cloude Agent/App/AppDelegate+MessageHandling.swift` | Route 3 new messages |
| `linux-relay/handlers.js` | Route 3 new messages |
