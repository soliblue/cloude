# Round: EnvironmentConnection boundary verification

## Plan
- Scope: environment-scoped ownership for conversation-bound file preview, file tree browse, git status, and git diff in iOS.
- Out of scope for approval: `@` file-search suggestions and disconnect-fallback log cleanliness, because this round did not produce clean comparable product-level evidence for those paths.
- Reproduction: connect two environments, bind one conversation to each environment in turn, then exercise file preview, files tab, git tab, and git diff while inspecting `app-debug.log` request routing.
- Target metrics: zero cross-environment request mismatches for file preview, files tab, git status, and git diff; one fresh request after each explicit conversation environment switch.
- Instrumentation: `EnvironmentConnection` request and response logging in `app-debug.log`.

## Allowed Files
- [EnvironmentConnection.swift](/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Shared/Services/EnvironmentConnection.swift)
- [ConversationOutput.swift](/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Shared/Services/ConversationOutput.swift)
- [EnvironmentConnectionObserver.swift](/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Shared/Views/EnvironmentConnectionObserver.swift)
- [FileBrowserView.swift](/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Features/Files/Views/FileBrowserView.swift)
- [FileTreeView.swift](/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Features/Files/Views/FileTreeView.swift)
- [FolderPickerView.swift](/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Features/Files/Views/FolderPickerView.swift)
- [FilePreviewView.swift](/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Features/Files/Views/FilePreviewView.swift)
- [GitChangesView.swift](/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Features/Git/Views/GitChangesView.swift)
- [GitDiffView.swift](/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Features/Git/Views/GitDiffView.swift)
- [SettingsView+Environments.swift](/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Features/Settings/Views/SettingsView+Environments.swift)
- [WorkspaceView+InputSection.swift](/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Features/Workspace/Views/WorkspaceView+InputSection.swift)
- [WorkspaceView+Windows.swift](/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Features/Workspace/Views/WorkspaceView+Windows.swift)
- [ConversationView.swift](/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Features/Conversation/Views/ConversationView.swift)
- [ConversationEnvironmentActions.swift](/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Features/Environment/Utils/ConversationEnvironmentActions.swift)
- [EnvironmentFolderPicker.swift](/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Features/Environment/Views/EnvironmentFolderPicker.swift)

## Baseline
- Build: `eb164edda9836db0a5b4196e9316855a95379870`
- `multi-env-file-routing`: pass. `README.md` preview requests were logged once on `ENV_A` and once on `ENV_B`.
- `folder-browse-and-preview`: fail. The repeated browse flow initially did not emit a second directory request after the environment switch, even though preview requests rerouted correctly.
- `git-status-and-diff-routing`: fail. The first git status request landed on the wrong environment; git diff itself rerouted correctly.
- `at-file-search-routing`: blocked. No clean simulator input path produced product-level file-search request logs.
- `disconnected-fallback-check`: mixed. No post-disconnect rerouting onto the wrong environment was observed, but disconnect logs were noisy because reconnect/setup paths also emitted disconnect lines.
- Baseline artifacts:
  - [baseline-routing-summary-20260419-234835.txt](/Users/soli/Desktop/CODING/cloude/.claude/agents/tester/output/baseline-routing-summary-20260419-234835.txt)
  - [baseline-conversation-env-mutates-active-default-20260419-234835.txt](/Users/soli/Desktop/CODING/cloude/.claude/agents/tester/output/baseline-conversation-env-mutates-active-default-20260419-234835.txt)

## Hypothesis
- File and git surfaces were caching window-local state and only reloading on path or visibility changes, not on conversation environment changes.
- `EnvironmentStore` was acting as a redraw proxy for nested `EnvironmentConnection` mutations, which made state ownership harder to predict.
- Conversation-scoped environment switches were mutating the app-wide default environment, creating unnecessary global side effects.

## Implementation
- Direct observation: moved connection-driven redraws to views that actually render connection state and removed `EnvironmentConnection -> EnvironmentStore` redraw forwarding.
- Reload triggers: reloaded file and git surfaces on environment changes; added first-appearance loading for the file tree.
- Semantics cleanup: conversation environment changes no longer rewrite `activeEnvironmentId`.
- Tester harness: added environment-routing scenario definitions for repeatable simulator verification.

Changed-file audit:
- `20/23` [EnvironmentConnection.swift](/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Shared/Services/EnvironmentConnection.swift)
- `0/2` [ConversationOutput.swift](/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Shared/Services/ConversationOutput.swift)
- `new` [EnvironmentConnectionObserver.swift](/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Shared/Views/EnvironmentConnectionObserver.swift)
- `21/0` [FileBrowserView.swift](/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Features/Files/Views/FileBrowserView.swift)
- `21/0` [FileTreeView.swift](/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Features/Files/Views/FileTreeView.swift)
- `12/0` [FolderPickerView.swift](/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Features/Files/Views/FolderPickerView.swift)
- `12/0` [FilePreviewView.swift](/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Features/Files/Views/FilePreviewView.swift)
- `17/0` [GitChangesView.swift](/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Features/Git/Views/GitChangesView.swift)
- `12/0` [GitDiffView.swift](/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Features/Git/Views/GitDiffView.swift)
- `25/10` [SettingsView+Environments.swift](/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Features/Settings/Views/SettingsView+Environments.swift)
- `65/50` [WorkspaceView+InputSection.swift](/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Features/Workspace/Views/WorkspaceView+InputSection.swift)
- `23/12` [WorkspaceView+Windows.swift](/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Features/Workspace/Views/WorkspaceView+Windows.swift)
- `11/3` [ConversationView.swift](/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Features/Conversation/Views/ConversationView.swift)
- `0/1` [ConversationEnvironmentActions.swift](/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Features/Environment/Utils/ConversationEnvironmentActions.swift)
- `0/1` [EnvironmentFolderPicker.swift](/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/Features/Environment/Views/EnvironmentFolderPicker.swift)

## After
- Builds:
  - iOS simulator build: pass
  - macOS agent build: pass, with the pre-existing unused `sessionId` warning in [RunnerManager+Callbacks.swift](/Users/soli/Desktop/CODING/cloude/Cloude/Cloude Agent/Services/RunnerManager+Callbacks.swift:83)
- `multi-env-file-routing`: pass. Preview requests remained correctly routed to `ENV_A` and `ENV_B` after the refactor.
- `folder-browse-and-preview`: pass on final rerun. Explicit switches to `ENV_A` and `ENV_B` each produced a fresh repo-root directory request and a fresh preview request on the selected environment.
- `git-status-and-diff-routing`: pass on rerun. Explicit switches to `ENV_A` and `ENV_B` each produced a fresh git status request and a fresh git diff request and response on the selected environment.
- Semantic invariant: forcing stored `activeEnvironmentId` to `ENV_B` before launch and then switching the active conversation to `ENV_A` and back to `ENV_B` left the stored `activeEnvironmentId` unchanged at `ENV_B` throughout.
- After artifacts:
  - [folder-browse-and-preview-20260419-233340-app-log.txt](/Users/soli/Desktop/CODING/cloude/.claude/agents/tester/output/folder-browse-and-preview-20260419-233340-app-log.txt)
  - [folder-browse-and-preview-20260419-233340-debug-metrics.txt](/Users/soli/Desktop/CODING/cloude/.claude/agents/tester/output/folder-browse-and-preview-20260419-233340-debug-metrics.txt)
  - [folder-browse-and-preview-20260419-233340-key-lines.txt](/Users/soli/Desktop/CODING/cloude/.claude/agents/tester/output/folder-browse-and-preview-20260419-233340-key-lines.txt)
  - [simulator-20260419-233447.png](/Users/soli/Desktop/CODING/cloude/.claude/agents/tester/output/simulator-20260419-233447.png)
  - [git-diff-routing-after-20260419-234250.txt](/Users/soli/Desktop/CODING/cloude/.claude/agents/tester/output/git-diff-routing-after-20260419-234250.txt)
  - [conversation-env-no-active-mutation-controlled-20260419-234342.txt](/Users/soli/Desktop/CODING/cloude/.claude/agents/tester/output/conversation-env-no-active-mutation-controlled-20260419-234342.txt)

## Verdict
- Approved for verified scope: file preview routing, files tab browse routing, git status routing, git diff routing, and conversation-scoped environment switching semantics.
- Residual risk: `at-file-search-routing` still lacks clean simulator automation, so file-search suggestion routing is not yet behaviorally verified in this round.
- Residual risk: disconnect fallback still needs a cleaner scenario that separates reconnect/setup noise from true rerouting.
- Lesson: environment-bound views need reload triggers on owner changes, not just path changes; otherwise routing bugs hide behind cached window state.
