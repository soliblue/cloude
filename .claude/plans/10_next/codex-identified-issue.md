# Codex identified render invalidation issues

## Goal

Capture simulator evidence for unnecessary SwiftUI invalidation during chat sends, fix the highest-signal causes, and keep user-visible behavior intact.

## Current status

This is no longer just a hypothesis ticket. The highest-signal issues were cut and rerun in Simulator.

Verified wins:
- Hidden `FileTreeView` and `GitView` no longer stay mounted behind opacity in chat sessions.
- `ChatViewBody` no longer invalidates directly on `QueryController<ChatMessage>`.
- The chat cost pill no longer queries every `ChatMessage`.
- Git pill data still refreshes while chat is focused.
- The keyboard-risk path improved materially: the final targeted git-status probe no longer showed `ChatInputBar` inside the `GitStatus.changes` invalidation window.
- Streaming markdown no longer reparses unfinished inline markers as complete formatting, and the streaming block diff evidence now shows additive block growth instead of block removal churn.

## Baseline

Early mixed run evidence showed broad invalidation dominated by shared observation:
- `ChatViewBody`: `38` invalidations, including `30` from `QueryController<ChatMessage>`
- `SessionViewTabsChatLabel`: `32` invalidations, mostly from `QueryController<ChatMessage>`
- `ChatInputBar`: `16` invalidations
- `SessionView`: `12` invalidations
- `ChatView`: `12` invalidations
- Cross-feature invalidations included chat labels reacting to git changes and git labels reacting to chat changes.

## Verified changes

### 1. Move the transcript query lower

Changed:
- `clients/ios/src/Features/Chat/UI/ChatView.swift`
- `clients/ios/src/Features/Chat/UI/ChatViewMessageList.swift`

Result:
- `ChatViewBody QueryController<ChatMessage>` is now `0` in current mixed runs.

### 2. Stop keeping all tabs mounted

Changed:
- `clients/ios/src/Features/Sessions/UI/SessionView.swift`
- `clients/ios/src/Features/Sessions/UI/SessionViewContent.swift`
- `clients/ios/src/Features/Sessions/UI/SessionViewHeader.swift`

Result:
- The hidden `GitView` and `FileTreeView` no longer sit behind opacity and invalidate the active chat tree just by existing.

### 3. Preserve git pill behavior without remounting hidden `GitView`

Changed:
- `clients/ios/src/Features/Git/Logic/GitService.swift`
- `clients/ios/src/Features/Git/UI/GitView.swift`
- `clients/ios/src/Features/Sessions/UI/SessionView.swift`

Result:
- Git refresh now lives in feature logic instead of depending on a hidden tab view being mounted.
- The git pill still updates while chat is focused.
- Screenshot evidence still shows git counts in the tab pill after the optimization.

### 4. Narrow the chat cost pill to session-level state

Changed:
- `clients/ios/src/Features/Sessions/Logic/Session.swift`
- `clients/ios/src/Features/Chat/Logic/ChatActions.swift`
- `clients/ios/src/Features/Sessions/UI/SessionViewTabsChatLabel.swift`

Result:
- The chat cost pill no longer observes the full message list.
- `TabsChat QueryController<ChatMessage>` is now `0` in current mixed runs.

### 5. Stabilize the input bar boundary

Changed:
- `clients/ios/src/Features/Chat/UI/ChatInputBar.swift`
- `clients/ios/src/Features/Chat/UI/ChatView.swift`

Result:
- `ChatInputBar` now has an explicit equatable boundary.
- Final mixed run: `ChatInputBar @self` dropped to `2`.
- Final targeted git-status probe: `SessionView`, `ChatView`, and `ChatViewBody` still reevaluate on `GitStatus.changes`, but `ChatInputBar` no longer appears in that invalidation window.
- This is the strongest current evidence that the keyboard auto-dismiss root cause was narrowed to the input bar boundary rather than the whole chat shell.

### 6. Reduce streaming markdown churn

Changed:
- `clients/ios/src/Features/Chat/Logic/ChatMarkdownParserInlineFormatting.swift`
- `clients/ios/src/Features/Chat/UI/ChatViewMessageListRowStreamingMarkdown.swift`

Result:
- Unclosed inline markers no longer retroactively restyle streamed text.
- Perf logs now show `block diff` events adding new blocks without removing prior frozen blocks in the final streaming path.
- That is strong evidence against the earlier paragraph-height wobble coming from retroactive block replacement.

## Current evidence

### Final mixed run

Artifact:
- `.claude/agents/tester/output/render-round20-final-mixed-run.txt`
- `.claude/agents/tester/output/render-round20-final-mixed-oslog.txt`

Key counts:
- `ChatInputBar @self`: `2`
- `ChatViewBody @self`: `5`
- `ChatViewBody QueryController<ChatMessage>`: `0`
- `TabsChat QueryController<ChatMessage>`: `0`
- `TabsGit QueryController<ChatMessage>`: `0`
- `TabsChat GitStatus.changes`: `1`
- `TabsGit GitStatus.changes`: `1`

Perf:
- `chat.firstToken`: `7470ms`
- `chat.complete`: `26693ms`

### Targeted keyboard-risk probe

Artifact:
- `.claude/agents/tester/output/render-round19-keyboard-git-oslog.txt`

Observed behavior during `GitStatus.changes`:
- `SessionView` changed
- `ChatView` changed
- `ChatViewBody` changed
- `SessionViewTabsChatLabel` changed
- `SessionViewTabsGitLabel` changed
- `ChatInputBar` did not appear in the `GitStatus.changes` window after the equatable boundary was added

Interpretation:
- Git refresh still bubbles through the session shell, but the input bar itself is now insulated from that update path.
- That is the most relevant change for keyboard stability.

### Behavior preservation artifact

Artifact:
- `.claude/agents/tester/output/render-round10-git-refresh-service.png`

Visible checks:
- Git pill still shows change counts.
- Chat cost pill still shows a dollar value.
- The rich mixed response still renders markdown sections and tool pills.

## Remaining risk

These are the remaining items that still need manual device validation, not because the simulator evidence is ambiguous, but because the interaction is inherently tactile:
- Confirm the keyboard stays up while typing when background git status updates arrive.
- Confirm paragraph-height stability on a real streamed long answer while actively watching the transcript.

Simulator evidence now supports the current claim set:
- The old invalidation hotspots were real.
- The biggest ones were cut.
- The git pill still works.
- The input bar is no longer in the git-status invalidation window.
