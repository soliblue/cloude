# Git Revert Changes

Allow reverting git changes directly from the git tab -- both per-file and all at once.

## Goals
- Revert all button in the status header (e.g. `arrow.uturn.backward` icon next to the branch info)
- Swipe-to-revert or revert button on each file row in the unstaged section
- Staged files: unstage only (not discard) -- `git reset HEAD <file>`
- Unstaged files: discard changes -- `git checkout -- <file>` (or `git restore <file>`)
- Revert all: `git checkout -- .` for all unstaged, or optionally unstage all staged too
- Confirmation alert before reverting (destructive action)
- Refresh git status after revert

## Approach
- New `ClientMessage` cases: `gitRevertFile(repoPath: String, filePath: String)` and `gitRevertAll(repoPath: String)`
- Mac agent `GitService` handles the git commands
- Linux relay adds handler for the same messages
- iOS sends the message, waits for updated `gitStatus` response (reuse existing refresh flow)
- Revert all button in `statusHeader` -- only visible when `status.hasChanges`
- Per-file: swipe action on `GitFileRow` (trailing swipe, red, `arrow.uturn.backward` icon)

## Files
- `CloudeShared/Messages/ClientMessage.swift` -- 2 new cases
- `Cloude Agent/Services/GitService.swift` -- `revertFile`, `revertAll` methods
- `Cloude Agent/App/AppDelegate+MessageHandling.swift` -- route new messages
- `linux-relay/handlers.js` -- handle git revert messages
- `Cloude/UI/GitChangesView.swift` -- revert all button in header
- `Cloude/UI/GitChangesView+Components.swift` -- swipe action on file row
- `Cloude/Services/ConnectionManager+API.swift` -- send revert messages

## Open Questions
- Should "revert all" also unstage staged files, or only discard unstaged?
- Staged files: just unstage or also discard? (unstage is safer)
