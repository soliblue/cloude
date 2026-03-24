# Branch-per-Conversation via Git Worktrees

## Context

All conversations share the same working directory. When one conversation switches branches, every other conversation sees the change. Git worktrees solve this by creating separate checkouts that share the same `.git` history.

This is opt-in. Most conversations use the default directory. When a user "attaches" a branch to a conversation, the relay creates a worktree and uses it as that conversation's working directory.

## Design

Worktrees live at `<repo>/.cloude-worktrees/<sanitized-branch>/` (slashes replaced with `--`). Add `.cloude-worktrees` to `.gitignore`.

### Relay: `linux-relay/handlers-worktree.js` (new file)

Two handlers following the pattern in `handlers-git.js`:

**`handleAttachBranch(repoPath, branch, conversationId, ws, sendTo)`**
1. Sanitize branch name (`/` -> `--`)
2. Worktree path = `<repoPath>/.cloude-worktrees/<sanitized>`
3. If directory exists, skip creation
4. Run `git worktree add <path> <branch>` (if branch doesn't exist locally, try `-b <branch> origin/<branch>`)
5. Send `{ type: 'branch_attached', branch, worktreePath, conversationId }`

**`handleListBranches(repoPath, ws, sendTo)`**
1. `git branch --format='%(refname:short)'` for local branches
2. `git rev-parse --abbrev-ref HEAD` for current
3. Send `{ type: 'branch_list', branches, current }`

### Relay: `linux-relay/handlers.js`

Add two cases:
- `attach_branch` -> `handleAttachBranch(msg.workingDirectory, msg.branch, msg.conversationId, ws, sendTo)`
- `list_branches` -> `handleListBranches(msg.workingDirectory, ws, sendTo)`

### Shared: `ClientMessage.swift`

Add two cases:
- `.attachBranch(branch: String, workingDirectory: String, conversationId: String)`
- `.listBranches(workingDirectory: String)`

Add encoding in `ClientMessage+Encoding.swift`. Add `branch`, `branches`, `current`, `worktreePath` to CodingKeys.

### Shared: `ServerMessage.swift`

Add two cases:
- `.branchAttached(branch: String, worktreePath: String, conversationId: String)`
- `.branchList(branches: [String], current: String)`

Add encoding in `ServerMessage+Encoding.swift`, decoding in `ServerMessage+Decoding.swift`.

### iOS: `Conversation.swift`

Add three optional fields:
- `var attachedBranch: String?`
- `var worktreePath: String?`
- `var originalWorkingDirectory: String?` (repo path before worktree override)

Update `init`, `init(from:)`, and `CodingKeys`.

### iOS: `ConnectionManager+API.swift`

Add two methods:
- `func attachBranch(branch:workingDirectory:conversationId:environmentId:)`
- `func listBranches(workingDirectory:environmentId:)`

### iOS: Event handling

On `branchAttached`: set conversation's `attachedBranch`, `worktreePath`, save `originalWorkingDirectory`, override `workingDirectory` to worktree path.

On `branchList`: store for UI consumption.

### iOS: `WindowEditSheet+Form.swift`

After `EnvironmentFolderPicker`, add a branch row:
- No branch attached: "Branch" label + button opening a branch picker sheet
- Branch attached: branch name pill + detach button (xmark restores `originalWorkingDirectory`, clears branch fields)

Branch picker sheet: on appear calls `listBranches`, shows searchable list, tapping attaches.

### Cleanup

- **Detach**: iOS clears conversation fields, restores `originalWorkingDirectory`. Worktree stays on disk (cheap, avoids coordination if multiple conversations share a branch).
- **On delete**: if conversation has `attachedBranch`, just clear state. Worktrees are prunable with `git worktree prune`.
- **Manual**: user can run `git worktree prune` or `git worktree remove` to clean up.

## Files to modify

1. `linux-relay/handlers-worktree.js` (new)
2. `linux-relay/handlers.js` - add cases
3. `.gitignore` - add `.cloude-worktrees`
4. `Cloude/CloudeShared/.../ClientMessage.swift` - add cases
5. `Cloude/CloudeShared/.../ClientMessage+Encoding.swift` - add encoding
6. `Cloude/CloudeShared/.../ServerMessage.swift` - add cases + CodingKeys
7. `Cloude/CloudeShared/.../ServerMessage+Encoding.swift` - add encoding
8. `Cloude/CloudeShared/.../ServerMessage+Decoding.swift` - add decoding
9. `Cloude/Cloude/Models/Conversation.swift` - add fields
10. `Cloude/Cloude/Services/ConnectionManager+API.swift` - add methods
11. `Cloude/Cloude/UI/WindowEditSheet+Form.swift` - branch row + picker

## Verification

1. Send `list_branches` via WebSocket, verify relay returns branch list
2. Send `attach_branch` with an existing branch, verify worktree created at expected path
3. Send `chat` with the worktree path as `workingDirectory`, verify CLI operates in the worktree
4. In iOS: attach branch to conversation, verify git status/diff/file browser all use worktree
5. Detach branch, verify conversation returns to original working directory
6. Check `.cloude-worktrees/` directory exists with correct structure
