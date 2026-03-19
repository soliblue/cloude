# Git Revert Changes

Allow reverting git changes directly from the git tab — section-level buttons only, no swipe, no confirmation dialogs.

## Goals
- "Unstage All" button in the Staged section header
- "Discard All" button in the Changes section header
- Taps fire immediately, no confirmation alert
- Refresh git status automatically after revert

## Design
Both buttons live in the section headers (`filesList`), not the top `statusHeader`.

```
Staged                    [↩ Unstage All]
  file.swift

Changes                   [↩ Discard All]
  modified.swift
  untracked.txt
```

## Git Commands (state-aware)

**Unstage All:**
```
git restore --staged -- .
```

**Discard All (must handle both tracked and untracked):**
```
git restore --worktree -- .   (tracked changes)
git clean -f                  (untracked files)
```

## Error Handling
`runGit` currently swallows errors. Need to surface exit status for write operations — add a throwing variant or fix return type for revert commands.

## Refresh Flow
After revert, server explicitly sends updated `gitStatusResult` by re-running gitStatus inline. Reuses existing queue/in-flight mechanism.

## Linux Relay
Use `execFileSync` with argv arrays (not string interpolation) to avoid quoting issues with filenames.

## Files
- `CloudeShared/Messages/ClientMessage.swift` — 2 new cases: `gitUnstageAll(repoPath:)`, `gitDiscardAll(repoPath:)`
- `Cloude Agent/Services/GitService.swift` — `unstageAll`, `discardAll` methods
- `Cloude Agent/App/Cloude_AgentApp+FileHandlers.swift` — route new messages, send gitStatus after
- `linux-relay/handlers-git.js` — handle both new message types
- `Cloude/UI/GitChangesView.swift` — buttons in section headers
- `Cloude/Services/ConnectionManager+API.swift` — `gitUnstageAll`, `gitDiscardAll` methods
