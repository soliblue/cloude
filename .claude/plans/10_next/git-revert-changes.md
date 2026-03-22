# Git Revert Changes {arrow.uturn.backward}
<!-- priority: 8 -->
<!-- tags: git, ui, agent, relay -->

> Add Unstage All and Discard All buttons to the git tab section headers.

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

## Git Commands

**Unstage All:**
```
git restore --staged -- .
```

**Discard All (must handle both tracked and untracked):**
```
git restore --worktree -- .   (tracked changes)
git clean -f                  (untracked files)
```

## Implementation

### Layer 1: Shared Models (CloudeShared)

**`ClientMessage.swift`** - add 2 cases after `gitCommit`:
```swift
case gitUnstageAll(path: String)
case gitDiscardAll(path: String)
```

**`ClientMessage.swift` CodingKeys** - add `path` (already exists, no change needed)

**`ClientMessage+Encoding.swift`** - add encoding for 2 new cases after `.gitCommit`:
```swift
case .gitUnstageAll(let path):
    try container.encode("git_unstage_all", forKey: .type)
    try container.encode(path, forKey: .path)
case .gitDiscardAll(let path):
    try container.encode("git_discard_all", forKey: .type)
    try container.encode(path, forKey: .path)
```

No new ServerMessage types needed. Both operations respond with the existing `gitStatusResult` after completing.

### Layer 2: Linux Relay

**`handlers-git.js`** - add 2 new exported functions:

```javascript
export function handleGitUnstageAll(path, ws, sendTo) {
  execSync('git restore --staged -- .', { cwd: path })
  handleGitStatus(path, ws, sendTo) // re-send status
}

export function handleGitDiscardAll(path, ws, sendTo) {
  execSync('git restore --worktree -- .', { cwd: path })
  execSync('git clean -f', { cwd: path })
  handleGitStatus(path, ws, sendTo) // re-send status
}
```

Use `execFileSync` with argv arrays (not string interpolation) to match existing pattern safety. Wrap in try/catch with `sendError`.

**`handlers.js`** - add 2 cases in the switch after `git_commit`:
```javascript
case 'git_unstage_all':
  handleGitUnstageAll(msg.path, ws, sendTo)
  break
case 'git_discard_all':
  handleGitDiscardAll(msg.path, ws, sendTo)
  break
```

### Layer 3: Mac Agent

**`GitService.swift`** - add 2 static methods after `commit()`:

```swift
static func unstageAll(at path: String) -> Result<Void, Error> {
    // runGit(["restore", "--staged", "--", "."], at: path)
    // need exit status check - runGit currently swallows errors
}

static func discardAll(at path: String) -> Result<Void, Error> {
    // runGit(["restore", "--worktree", "--", "."], at: path)
    // runGit(["clean", "-f"], at: path)
}
```

**Error handling note**: `runGit` currently returns `""` on failure. These are write operations so we need to check `process.terminationStatus`. Options:
1. Add a `runGitChecked` variant that throws on non-zero exit
2. Check `terminationStatus` inline in the two new methods

Option 2 is simpler (no new abstractions for 2 uses).

**`Cloude_AgentApp+FileHandlers.swift`** - add 2 handlers after `handleGitCommit`:

```swift
func handleGitUnstageAll(_ path: String, connection: NWConnection) {
    let expandedPath = path.expandingTildeInPath
    _ = GitService.unstageAll(at: expandedPath)
    handleGitStatus(expandedPath, connection: connection)
}

func handleGitDiscardAll(_ path: String, connection: NWConnection) {
    let expandedPath = path.expandingTildeInPath
    _ = GitService.discardAll(at: expandedPath)
    handleGitStatus(expandedPath, connection: connection)
}
```

**`AppDelegate+MessageHandling.swift`** - add 2 cases after `.gitCommit`:
```swift
case .gitUnstageAll(let path):
    handleGitUnstageAll(path, connection: connection)

case .gitDiscardAll(let path):
    handleGitDiscardAll(path, connection: connection)
```

### Layer 4: iOS App

**`ConnectionManager+API.swift`** - add 2 convenience methods after `gitCommit`:
```swift
func gitUnstageAll(path: String, environmentId: UUID? = nil) {
    connectionForSend(environmentId: environmentId)?.send(.gitUnstageAll(path: path))
}
func gitDiscardAll(path: String, environmentId: UUID? = nil) {
    connectionForSend(environmentId: environmentId)?.send(.gitDiscardAll(path: path))
}
```

**`GitChangesView.swift`** - modify `filesList` section headers to include buttons:

Staged section header becomes `HStack` with "Unstage All" button:
```swift
Section {
    ...
} header: {
    HStack {
        Text("Staged").font(.system(size: 11, weight: .semibold)).textCase(.uppercase)
        Spacer()
        Button { unstageAll() } label: {
            Label("Unstage All", systemImage: "arrow.uturn.backward")
                .font(.system(size: 11))
        }
    }
}
```

Changes section header becomes `HStack` with "Discard All" button:
```swift
Section {
    ...
} header: {
    HStack {
        Text("Changes").font(.system(size: 11, weight: .semibold)).textCase(.uppercase)
        Spacer()
        Button { discardAll() } label: {
            Label("Discard All", systemImage: "arrow.uturn.backward")
                .font(.system(size: 11))
                .foregroundColor(.pastelRed)
        }
    }
}
```

Add two private methods:
```swift
private func unstageAll() {
    connection.gitUnstageAll(path: repoPath, environmentId: environmentId)
    loadStatus() // optimistic reload
}

private func discardAll() {
    connection.gitDiscardAll(path: repoPath, environmentId: environmentId)
    loadStatus()
}
```

No need for `loadStatus()` call actually - the server sends `gitStatusResult` back after the operation, and the existing `.onReceive(connection.events)` handler will pick it up.

## Files Summary

### Modified (7)
| File | What |
|------|------|
| `CloudeShared/Messages/ClientMessage.swift` | 2 new cases |
| `CloudeShared/Messages/ClientMessage+Encoding.swift` | Encode 2 new cases |
| `Cloude Agent/Services/GitService.swift` | `unstageAll`, `discardAll` methods with exit status check |
| `Cloude Agent/App/Cloude_AgentApp+FileHandlers.swift` | 2 new handler methods |
| `Cloude Agent/App/AppDelegate+MessageHandling.swift` | Route 2 new messages |
| `Cloude/Services/ConnectionManager+API.swift` | 2 convenience methods |
| `Cloude/UI/GitChangesView.swift` | Buttons in section headers |

### Relay (1)
| File | What |
|------|------|
| `linux-relay/handlers-git.js` | 2 new exported functions |
| `linux-relay/handlers.js` | Route 2 new message types |

### New (0)
No new files needed.

## Tasks

### Shared models
- [ ] Add `gitUnstageAll(path:)` and `gitDiscardAll(path:)` cases to `ClientMessage.swift`
- [ ] Add encoding for both cases in `ClientMessage+Encoding.swift`

### Linux relay
- [ ] Add `handleGitUnstageAll` and `handleGitDiscardAll` to `handlers-git.js`
- [ ] Route `git_unstage_all` and `git_discard_all` in `handlers.js`

### Mac agent
- [ ] Add `unstageAll(at:)` and `discardAll(at:)` to `GitService.swift` with exit status check
- [ ] Add `handleGitUnstageAll` and `handleGitDiscardAll` to `Cloude_AgentApp+FileHandlers.swift`
- [ ] Route both cases in `AppDelegate+MessageHandling.swift`

### iOS app
- [ ] Add `gitUnstageAll(path:)` and `gitDiscardAll(path:)` to `ConnectionManager+API.swift`
- [ ] Add "Unstage All" button in Staged section header of `GitChangesView.swift`
- [ ] Add "Discard All" button in Changes section header of `GitChangesView.swift`
