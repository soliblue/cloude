# Autocomplete Management

Full autocomplete system: `/autocomplete` sheet, Sonnet-powered deduplication, fuzzy matching. Per-environment storage, cross-environment search.

## Goals
- `/autocomplete` slash command opens sheet with all saved messages
- Tap to fill input, trash icon to delete entries
- Refresh button (top-left, rotating) triggers Sonnet cleanup
- Auto-trigger cleanup every ~20 messages sent
- Fuzzy matching in inline suggestions (prefix > contains > fuzzy)
- Per-environment storage, cross-environment search

## Architecture Decision: Server-side, per-environment

**Previous approach (phone-only):** autocomplete data lived only in iOS UserDefaults. Required complex WebSocket round-trips to send the full list to the agent for Sonnet cleanup and back. Single global list, no environment separation.

**New approach (server-side, per-environment, like plans/memories):** autocomplete data lives as a file on each server. iOS caches per-environment and aggregates for search/suggestions.

### Why server-side is better
- **I (Claude CLI) can read/write it directly** as a file, no MCP tools needed
- **Sonnet cleanup is trivial** - agent reads file, pipes to `claude --model sonnet --print`, writes back
- **Survives app reinstalls** - data persists on server
- **Same pattern as plans/memories** - no new architecture to maintain
- **Simpler message types** - just `getAutocomplete` (fetch) and `saveAutocomplete` (push)

### Per-environment design
Each environment (Mac home, Linux medina, etc.) maintains its own autocomplete file with up to 500 entries. The iOS app:
- **Stores** per-environment: `UserDefaults` keyed by environment ID
- **Saves** to the active environment only (the one the current conversation belongs to)
- **Searches** across ALL cached environments when showing inline suggestions or sheet content
- **Cleans** per-environment (Sonnet runs on each server's own file)
- **Deletes** from the correct environment (sheet shows which env each entry came from, or just deletes from all)

This means you naturally build up different suggestion sets per server (e.g. coding commands on Mac, server ops on medina) while still getting the full picture when typing.

### Data flow
```
Mac (home):    .cloude/autocomplete.txt    (up to 500 lines)
Medina:        .cloude/autocomplete.txt    (up to 500 lines)
               ↕ read/write by agent handler on each server

iOS app:       UserDefaults["autocomplete_{envId}"]  (cached per env)
               ↕ syncs on connect + every ~20 messages + manual refresh
               → inline suggestions search ALL env caches combined
```

1. **On authenticate**: iOS sends `getAutocomplete` to that env, agent reads file, responds with `autocompleteData`
2. **On user send**: iOS saves to local cache for active env AND sends `saveAutocompleteEntry(text)` to agent
3. **On refresh / every ~20 sends**: iOS sends `cleanAutocomplete` to active env, agent reads file -> Sonnet -> writes cleaned file -> responds with `autocompleteData`
4. **On `/autocomplete` sheet open**: shows merged data from all env caches, refresh button triggers cleanup on active env
5. **CLI direct access**: just read/write `.cloude/autocomplete.txt` on the server

## Approach

### 1. Server file + agent handler
- File: `.cloude/autocomplete.txt` (one message per line, most recent first, max 500)
- Mac agent: `AutocompleteDataService.swift` (new) with `load()`, `save(entry:)`, `delete(entry:)`, `replaceAll()`, `clean()` (spawns Sonnet)
- Linux relay: `handlers-autocomplete.js` (new) with same operations
- Dedup on save (case-insensitive, keep most recent)

### 2. Shared models (CloudeShared)
- `ClientMessage.getAutocomplete` - fetch full list from this env
- `ClientMessage.saveAutocompleteEntry(text: String)` - save single new entry
- `ClientMessage.cleanAutocomplete` - trigger Sonnet cleanup
- `ClientMessage.deleteAutocompleteEntry(text: String)` - delete single entry
- `ServerMessage.autocompleteData(messages: [String])` - full list response
- `ConnectionEvent.autocompleteData(environmentId: UUID?, messages: [String])` - iOS internal event (includes env ID for correct cache update)

### 3. iOS app
- `MessageHistory`: refactor to per-env storage
  - `save(_ text: String, environmentId: UUID?)` - save locally + send to server
  - `delete(_ text: String, environmentId: UUID?)` - delete locally + send to server
  - `replaceAll(_ messages: [String], environmentId: UUID?)` - replace cache for one env
  - `loadAll() -> [String]` - merge all env caches, deduplicated
  - `suggestions(for query: String) -> [String]` - fuzzy search across all envs
- `MainChatView+AutocompleteSheet.swift` (new): sheet with search, delete, refresh
- `SlashCommand.swift`: add `autocomplete` command
- `MainChatView+Messaging.swift`: handle `/autocomplete`
- `MainChatView.swift`: state, sheet
- `MainChatView+EventHandling.swift`: handle `autocompleteData` -> update correct env cache
- `EnvironmentConnection+Handlers.swift`: send `getAutocomplete` on authenticate

## Files

### New
- `Cloude Agent/Services/AutocompleteDataService.swift` - file read/write/clean
- `Cloude/UI/MainChatView+AutocompleteSheet.swift` - sheet UI
- `linux-relay/handlers-autocomplete.js` - relay handler

### Modified
- `CloudeShared/Messages/ClientMessage.swift` - 4 new cases
- `CloudeShared/Messages/ServerMessage.swift` - 1 new case
- `CloudeShared/Messages/ServerMessage+Encoding.swift` - encoder
- `Cloude/Services/MessageHistory.swift` - per-env storage, fuzzy matching
- `Cloude/Services/ConnectionEvent.swift` - autocompleteData case
- `Cloude/Services/ConnectionManager+API.swift` - convenience methods
- `Cloude/Services/EnvironmentConnection+MessageHandler.swift` - handle response
- `Cloude/Services/EnvironmentConnection+Handlers.swift` - fetch on auth
- `Cloude/UI/SlashCommand.swift` - add command
- `Cloude/UI/MainChatView.swift` - state + sheet
- `Cloude/UI/MainChatView+Messaging.swift` - handle /autocomplete
- `Cloude/UI/MainChatView+EventHandling.swift` - handle event
- `Cloude Agent/App/AppDelegate+MessageHandling.swift` - route messages
- `linux-relay/handlers.js` - route messages
