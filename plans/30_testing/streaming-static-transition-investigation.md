## Streaming-to-static transition investigation

Date: 2026-03-28

### Symptom

When assistant streaming completes, the message briefly disappears and then comes back after a manual refresh.

### Relevant architecture

- `ForEach(messages)` renders either `ObservedMessageBubble` or static `MessageBubble`
- During streaming, `ObservedMessageBubble` observes `ConversationOutput` and passes `liveText` / `liveToolCalls`
- After streaming, the row should switch to static `MessageBubble`, which should render persisted `message.text` / `message.toolCalls`
- `StreamingMarkdownView` keeps incremental parse state in `@State` using `frozenBlocks` and `tailBlocks`

### Changes and experiments in progress

#### 1. Branch identity experiment

Files:
- `Cloude/Cloude/UI/ConversationView+MessageScroll.swift`

Current state:
- live branch uses `.id("\\(message.id)-live")`
- static branch uses `.id("\\(message.id)-\\(message.isQueued)")`

Reason:
- This was used to force SwiftUI to destroy and recreate the row subtree on live/static transition
- It avoids the disappearing symptom, but it also forces the markdown subtree to be rebuilt and reparsed

Status:
- kept in the worktree for comparison/debugging
- not considered the preferred final fix

#### 2. Incremental markdown block identity stabilization

Files:
- `Cloude/Cloude/UI/StreamingBlock.swift`
- `Cloude/Cloude/UI/StreamingMarkdownView.swift`

Current state:
- added `StreamingBlock.prefixed(_:)`
- `StreamingMarkdownView.allBlocks` prefixes tail block ids with `tail-`

Reason:
- avoids collisions between frozen and tail block identities while incremental parsing is active

Status:
- kept as part of the investigation state

#### 3. Finalization handoff fix

Files:
- `Cloude/Cloude/Services/ConnectionManager+ConversationOutput.swift`
- `Cloude/Cloude/UI/MessageBubble.swift`

Current state:
- `liveMessageId` is now `@Published`
- `ConversationOutput.reset()` clears `liveMessageId` before clearing `text` / `toolCalls`
- `MessageBubble` now falls back to stored `message.text` / `message.toolCalls` when live values are present but empty

Reason:
- previously `reset()` published `text = ""` before `liveMessageId = nil`
- `text` was `@Published`, but `liveMessageId` was not
- this allowed one extra live render with empty `liveText`, which explains the transient disappearance

Assessment:
- this is the current best explanation of the bug
- `ChatMessage.Equatable` does not appear to be the issue because it is synthesized and includes `text`
- there is no `.equatable()` wrapper in the relevant view path

### Debug logging added

Files:
- `Cloude/Cloude/UI/MessageBubble.swift`
- `Cloude/Cloude/Services/ConnectionManager+ConversationOutput.swift`

Current logs:
- `Bubble` render log includes `id`, `isLive`, `message.text.count`, `liveText.count`, and `effectiveText.count`
- `Bubble` also logs `isLive old->new`
- `Stream` logs `reset start` and `reset end` with `liveId`, `text.count`, `fullText.count`, `toolCalls.count`, and `isRunning`

What to look for:
- bad frame signature: `Bubble render ... isLive=true ... live=0ch effective=0ch`
- expected handoff: `Stream reset start` then `Bubble isLive true->false` then `Bubble render ... isLive=false ... effective>0`

### Verification

- `xcodebuild -list -project Cloude/Cloude.xcodeproj` succeeded
- a full simulator build was attempted with:
  `xcodebuild -project Cloude/Cloude.xcodeproj -scheme Cloude -configuration Debug -sdk iphonesimulator build`
- the build did not complete cleanly because of an unrelated package-side failure in `HighlightSwift`:
  `Internal Error: dataCorrupted(Swift.DecodingError.Context(... "Corrupted JSON" ...))`

### Recommended next step

Reproduce once with the new `Bubble` and `Stream` logs enabled and confirm the exact ordering around completion. If the disappearance is gone with the reset-order fix, the branch-specific `.id()` experiment can likely be removed and the row can keep stable identity.
