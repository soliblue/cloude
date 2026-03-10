# Unified Relay {arrow.triangle.merge}

> Consolidate Mac (Swift) and Linux (Node.js) relays into a single Node.js codebase

## Context

Both relays implement the same WebSocket protocol and handle the same message types. The JS relay is ~620 lines total vs thousands across Swift services. Maintaining two implementations means every new feature needs to be built twice.

## Gap Analysis

The JS relay is missing these Mac-only features that need porting:

- **HeartbeatService** - timer-based autonomous sessions, interval config, unread tracking
- **AutocompleteService** - conversation name suggestions
- **ResponseStore** - missed response storage when iOS disconnects
- **MemoryService** - reads both CLAUDE.md and CLAUDE.local.md (JS only reads local)

File/git/history/plans/terminal/transcribe handlers are functionally identical.

## Approach

1. Port the 4 missing services to Node.js
2. Wrap JS relay in a lightweight native shell for macOS menu bar (Electron/Tauri) if menu bar UI is still wanted
3. Drop the Swift agent, use JS relay on both platforms
4. Update fastlane/build scripts accordingly

## Open Questions

- Do we still need the menu bar UI or is headless fine?
- Electron vs Tauri vs pure headless for macOS?
