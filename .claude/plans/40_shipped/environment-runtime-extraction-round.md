# Round: Environment runtime extraction verification

## Plan
- Scope: verify that extracting file and git state into child runtimes does not change conversation-owned routing for file browse and preview, git status, or git diff on iOS.
- Reproduction: connect two environments, switch the active conversation between them, then repeat file and git flows while inspecting `app-debug.log` request routing.
- Target metrics: zero cross-environment request mismatches for file browse, file preview, git status, and git diff; fresh requests after each explicit environment switch.
- Instrumentation: `EnvironmentConnection` request and response logging in `app-debug.log`.

## Allowed Files
- [EnvironmentConnection.swift](/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Shared/Services/EnvironmentConnection.swift)
- [FilesRuntime.swift](/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Features/Files/Services/FilesRuntime.swift)
- [GitRuntime.swift](/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Features/Git/Services/GitRuntime.swift)
- [FileTreeView.swift](/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Features/Files/Views/FileTreeView.swift)
- [FileBrowserView.swift](/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Features/Files/Views/FileBrowserView.swift)
- [FolderPickerView.swift](/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Features/Files/Views/FolderPickerView.swift)
- [FilePreviewView.swift](/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Features/Files/Views/FilePreviewView.swift)
- [FilePreviewView+Loading.swift](/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Features/Files/Views/FilePreviewView+Loading.swift)
- [GitChangesView.swift](/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Features/Git/Views/GitChangesView.swift)
- [GitDiffView.swift](/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Features/Git/Views/GitDiffView.swift)
- [WorkspaceStore+Lifecycle.swift](/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Features/Workspace/Store/WorkspaceStore+Lifecycle.swift)
- [WorkspaceStore+EventHandling.swift](/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Features/Workspace/Store/WorkspaceStore+EventHandling.swift)
- [WorkspaceView+InputSection.swift](/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Features/Workspace/Views/WorkspaceView+InputSection.swift)
- [WorkspaceView+Windows.swift](/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Features/Workspace/Views/WorkspaceView+Windows.swift)

## Baseline
- Pre-change behavioral baseline already existed in [environment-connection-boundary-round.md](/Users/soli/Desktop/CODING/cloude/.claude/plans/20_active/environment-connection-boundary-round.md) for the same routing surfaces.

## Hypothesis
- The refactor is behavior-preserving because only ownership moved: `EnvironmentConnection` still transports messages, while file and git runtimes own caches, pending requests, and message handling.
- Forwarding child `objectWillChange` into `EnvironmentConnection` should preserve existing view redraw behavior without an observer rewrite.

## Implementation
- Added [FilesRuntime.swift](/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Features/Files/Services/FilesRuntime.swift) to own file browse state, file response state, file search state, chunk progress, cache, and file message handling.
- Added [GitRuntime.swift](/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Features/Git/Services/GitRuntime.swift) to own git status state, git log state, git diff state, pending git requests, and git message handling.
- Reduced [EnvironmentConnection.swift](/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Shared/Services/EnvironmentConnection.swift) to transport, auth, conversation streaming, and child-runtime composition.
- Migrated touched views and workspace actions to explicit `connection.files` and `connection.git` ownership.
- Forwarded child runtime change notifications through `EnvironmentConnection` so existing `EnvironmentConnectionObserver` redraw sites continue to update.

Changed-file audit:
- `36/249` [EnvironmentConnection.swift](/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Shared/Services/EnvironmentConnection.swift)
- `161/0 new` [FilesRuntime.swift](/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Features/Files/Services/FilesRuntime.swift)
- `138/0 new` [GitRuntime.swift](/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Features/Git/Services/GitRuntime.swift)
- `5/5` [FileTreeView.swift](/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Features/Files/Views/FileTreeView.swift)
- `3/3` [FileBrowserView.swift](/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Features/Files/Views/FileBrowserView.swift)
- `3/3` [FolderPickerView.swift](/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Features/Files/Views/FolderPickerView.swift)
- `6/6` [FilePreviewView.swift](/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Features/Files/Views/FilePreviewView.swift)
- `6/6` [FilePreviewView+Loading.swift](/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Features/Files/Views/FilePreviewView+Loading.swift)
- `7/7` [GitChangesView.swift](/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Features/Git/Views/GitChangesView.swift)
- `3/3` [GitDiffView.swift](/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Features/Git/Views/GitDiffView.swift)
- `3/3` [WorkspaceStore+Lifecycle.swift](/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Features/Workspace/Store/WorkspaceStore+Lifecycle.swift)
- `1/1` [WorkspaceStore+EventHandling.swift](/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Features/Workspace/Store/WorkspaceStore+EventHandling.swift)
- `1/1` [WorkspaceView+InputSection.swift](/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Features/Workspace/Views/WorkspaceView+InputSection.swift)
- `1/1` [WorkspaceView+Windows.swift](/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Features/Workspace/Views/WorkspaceView+Windows.swift)

## After
- Builds:
  - iOS simulator build: pass with `xcodebuild -project Cloude/Cloude.xcodeproj -scheme Cloude -destination 'id=8F3628CD-6895-4A0C-8651-A96B407FBD60' build`
  - macOS agent build: pass with `xcodebuild -project Cloude/Cloude.xcodeproj -scheme 'Cloude Agent' -destination 'platform=macOS' build`
- `folder-browse-and-preview`: pass. Directory and file preview requests routed to `ENV_A` first and `ENV_B` after the explicit environment switch.
- `git-status-and-diff-routing`: pass. Git status and git diff requests routed to `ENV_A` first and `ENV_B` after the explicit environment switch.
- Note: launcher reports use git head `eb164edd`, but the verification ran against the freshly built current workspace with the extraction applied.
- Artifacts:
  - [folder-browse-and-preview-routing-20260420-0042.log](/Users/soli/Desktop/CODING/cloude/.claude/agents/tester/output/folder-browse-and-preview-routing-20260420-0042.log)
  - [simulator-20260420-003427.png](/Users/soli/Desktop/CODING/cloude/.claude/agents/tester/output/simulator-20260420-003427.png)
  - [simulator-20260420-003430.png](/Users/soli/Desktop/CODING/cloude/.claude/agents/tester/output/simulator-20260420-003430.png)
  - [simulator-20260420-003434.png](/Users/soli/Desktop/CODING/cloude/.claude/agents/tester/output/simulator-20260420-003434.png)
  - [simulator-20260420-003437.png](/Users/soli/Desktop/CODING/cloude/.claude/agents/tester/output/simulator-20260420-003437.png)
  - [simulator-20260420-003432.png](/Users/soli/Desktop/CODING/cloude/.claude/agents/tester/output/simulator-20260420-003432.png)
  - [git-status-and-diff-routing-excerpt-20260420-004032.log](/Users/soli/Desktop/CODING/cloude/.claude/agents/tester/output/git-status-and-diff-routing-excerpt-20260420-004032.log)
  - [git-status-and-diff-routing-log-slice-20260420-003432.log](/Users/soli/Desktop/CODING/cloude/.claude/agents/tester/output/git-status-and-diff-routing-log-slice-20260420-003432.log)
  - [git-status-and-diff-routing-filtered-20260420-003432.log](/Users/soli/Desktop/CODING/cloude/.claude/agents/tester/output/git-status-and-diff-routing-filtered-20260420-003432.log)

## Verdict
- Pending reviewer judgment.
