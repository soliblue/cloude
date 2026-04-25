# Open issues (user-reported, unverified)

Running list of issues reported during dogfooding. Each gets a short note on symptom + suspected cause. Verification comes later, via logs added in the perf ticket.

## Chat

### Scroll feels laggy on message list (idle)
- **Symptom**: scrolling the chat list is not smooth even when nothing is streaming.
- **Suspected**: markdown re-parsed every render (`ChatViewMessageListRowMarkdown.swift:10`), `groupedMessages` recomputed every body eval (`ChatViewMessageList.swift:60`), `.animation(value:)` on list invalidating whole LazyVStack (`ChatViewMessageList.swift:33-34`), inline image decode (`ChatAttachmentThumbnail.swift:7`), unstable row IDs in streaming markdown.
- **Status**: needs empirical counters to confirm.

### ~~Typing in input bar drops FPS to ~46~~ — FIXED (commit 5bd0ed87)
- Split `ChatView` into outer + `ChatViewBody`; `@Query messages` now lives on `ChatViewBody`, `ChatInputBar` sits in `safeAreaInset` on the outer view and no longer re-evaluates on keystrokes. Removed `onGeometryChange` bar-height path.

### Git tab pill goes stale after a response
- **Symptom**: after an assistant response completes, the session's Git tab (and its badge/counts) still shows the pre-response state. Refresh happens only on manual re-open of the tab.
- **Suspected**: no git status refresh hook tied to chat-turn completion. `GitService` is called when the Git tab appears, but nothing re-fires on `result` events from the chat stream.
- **Status**: needs verification — confirm on the daemon side too (does `GET /sessions/:id/git/status` even reflect just-written files fast enough, or do we cache?).

### ~~Backgrounding mid-stream then reopening leaves the session silent~~ — FIXED (commit 5bd0ed87)
- `ChatView` now observes `scenePhase`; on `.active` it re-runs `resumeIfStuck`. `resumeIfStuck` proceeds whenever `session.isStreaming` is true (not only when a stuck message exists), so cold launches after a deploy kill between assistant blocks also resume. Delta-only replay via per-session `lastSeqs` + persisted `session.lastSeq` checkpoint prevents duplication.

### ~~Mid-stream content reflows / lists appear-disappear in already-rendered sections~~ — FIXED
- Streaming markdown no longer treats unfinished inline markers as complete formatting, and the renderer now freezes committed blocks more aggressively. Added block-diff probes and fixed the header transition path so a live paragraph no longer flips from plain text into `header + paragraph` after the fact, which was causing the visible jump on the first paragraph under a heading.

### ~~Keyboard dismisses itself in the active window while unrelated state changes land~~ — FIXED
- Hidden tabs no longer stay mounted behind opacity, the active chat shell observes less transcript state, and `ChatInputBar` now sits behind an explicit equatable boundary. In the targeted git-status probe, `SessionView`, `ChatView`, and `ChatViewBody` still reevaluate, but `ChatInputBar` no longer appears in the `GitStatus.changes` invalidation window.

### ~~Typing in a new tab loses text + keyboard when a response completes elsewhere~~ — FIXED (commit 815d7c5c)
- `ForEach(windows)` in `WindowsView` reused identities by index, so any `@Query<Window>` refire (triggered when another session's state changed) tore down `ChatInputBar` across windows and reset its `@State draft` + `@FocusState`. Pinned `.id(window.id)` on the per-window `SessionView` to keep each window's subtree stable across unrelated SwiftData updates.

### ~~iOS app restart interrupts in-flight agent tool calls~~ — FIXED (commit 5bd0ed87)
- Client disconnect no longer triggers any abort; `ChatService.consume`'s catch path keeps the stuck message in `.streaming` state instead of marking it failed. Daemon runner keeps running. On reconnect `resumeIfStuck` replays the ring buffer from the persisted checkpoint.

### ~~Sub-agent tool pills leak into main chat transcript~~ — FIXED
- iOS now preserves parent-child tool-call linkage, filters child tool calls out of the top-level transcript row, shows a child count on the parent Task pill, and renders the nested child tool calls inside the parent tool sheet instead of flattening them into the main chat.

### Expanded DebugOverlay pill looks cramped
- **Symptom**: when the FPS pill expands to reveal the Send Logs button, padding and spacing between FPS row and button are tight. No visual separator. Content doesn't breathe.
- **Note**: attempt to add full-width stretching, divider, and larger padding made it worse (edge-to-edge button felt wrong). Likely needs a proper designed layout, possibly a non-capsule shape when expanded, or just a tighter but clearly-separated two-row stack with more internal padding only.
- **Priority**: low. Functional is fine. Polish later.

### ~~Drawer open-close interaction feels binary and unpolished~~ — FIXED
- Replaced the boolean overlay drawer with a 3-pane horizontal shell: left sidebar page, center session page, right git page.
- Pane transitions now use bounded drag progress plus velocity-aware settle, so the shell can move left and right interactively instead of snapping only on drag end.
- Git is now a real full-width right screen while keeping the existing git pill and badge data intact.
- Verified with simulator pane logs (`windows pane 1->2`, `windows pane 2->1`) and full-width captures of both the left settings page and the right git page.

## Tooling / DX

### Agents cannot edit `.claude/` plans anymore
- **Symptom**: Anthropic added a permission gate on Edit/Write/mkdir/cp under `.claude/`. Every plan write, every ticket update, every memory edit now prompts for approval. Running headless (no human at the keyboard) this breaks the loop entirely.
- **Impact**: plan tickets, memory, skills, and agent configs can't be iterated on from inside a session. Worst for `.claude/plans/` since that's where ongoing work is tracked.
- **Workaround in place**: using a root-level `plans/` folder (gitignored) instead of `.claude/plans/` so agents can read/write freely.
- **Status**: needs upstream fix or a carve-out for `.claude/plans/` and `.claude/memory/`.
