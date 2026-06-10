---
title: "Streaming Robustness Audit"
description: "Ranked bug list from a four-agent audit of the streaming path, daemons, and iOS state; Linux daemon fixes shipped, iOS fixes open."
created_at: 2026-06-10
tags: ["streaming", "daemon", "reliability"]
icon: waveform.path.ecg
---

# Streaming Robustness Audit

Four parallel audits (Linux daemon, iOS streaming, protocol parity, iOS state) on 2026-06-10, plus a round-2 iOS UI audit (tool pills, markdown performance, UI sweep) the same day. Live token-by-token streaming is required product behavior; every fix below preserves it.

## Fixed (round 2, iOS)

R1. **Tool pill order flipping.** ChatToolCall.order restarted at 0 per message while the pill list buckets span multiple messages sorted by order alone, so orders collided and ties flipped per fetch. Order is now session-scoped monotonic, with a secondary id sort for legacy rows (ChatActions, ChatViewMessageListRowToolPillList).
R2. **Pills jump and open tool sheets self-dismiss at turn end.** Segments were ForEach-keyed by array offset; now keyed by stable identity (ChatViewMessageListGroup).
R3. **O(n^2) markdown parse while streaming.** Every delta re-parsed the whole message; now only the tail block re-parses via ChatMarkdownParser.parseResuming, byte-identical output, full-parse fallback for non-append updates.
R4. **Code blocks re-syntax-highlighted up to 60x/sec while streaming.** Memoized in ChatMarkdownSyntaxHighlighter.
R5. **Completed messages re-parsed on every scroll materialization.** ChatMarkdownParseCache (capped).
R6. **Stale streams tearing down the live stream's state** (abort + re-send, deep-link send, resume racing a dying connection). Per-stream generation tokens in ChatService; StreamingClient streams now cancel their URLSession task on termination.
R7. **Mid-stream drop while foregrounded never resumed.** Body errors now schedule resumeIfStuck after 3s with warm after_seq.
R8. **Daemon error events rendered as successful empty turns.** .error now surfaces as a failed assistant message (previously dead UI).
R9. **Messages stuck in .retrying forever** after EOF-before-first-event or abort-during-retry; reset to .failed so retry reappears.
R10. Small fixes: git changes list sorted by path (was nondeterministic per refresh), GitDiffSheet lazy rendering (full diffs froze the sheet), retry button state seeding on row recreation, fixed frames on two morphing SF Symbols, em dash removal.

## Fixed (round 3, all surfaces)

Linux daemon: git handlers now async (spawnSync froze all live streams during status/diff/log), git log tolerates tabs in commit subjects, image dropbox dirs keyed by session and replaced per message (was leaking forever), slow subscribers capped at 8MB buffered (destroyed; client resumes via after_seq), search depth aligned with macOS.

macOS daemon: runner restart serialized like Linux (was racing two claude processes per session; termination handler now retains the runner so the deferred spawn actually fires), abort escalates SIGINT to SIGKILL after 5s, trailing unterminated stdout line is parsed and emitted instead of dropped.

iOS: NDJSON framing on raw newline bytes (bytes.lines also split on NEL/U+2028/U+2029, silently dropping events), pager pan no longer hijacks swipes inside sheets or horizontal scrollers, sessions stuck streaming in background windows resume on launch (resumeAllStuck), git diff sheet holds a value snapshot instead of a deletable SwiftData model, endpoint deletion nils out referencing sessions, git refresh has an in-flight guard, sidebar unread dot and create-button gate use fetchLimit 1 queries, pending pill shimmer restarts after scroll recycle, cold resume preserves any live partial text, dead centerTabs plumbing deleted.

## Open: round 2 findings (iOS, medium)

R11. **Window pager pan recognizer hijacks horizontal gestures** inside sheets and horizontal scrollers; can switch panes behind a presented sheet. WindowsPagerGesture.swift:30-44.
R12. **Composer draft and attachments lost on session switch** (@State in ChatInputBar, torn down by .id(session.id)). Key drafts by session.
R13. **Full-resolution image decode in thumbnail bodies** causes scroll hitches with photo attachments. ChatAttachmentThumbnail.swift:7-11.
R14. **Pending pill shimmer freezes after scroll recycle** (ChatViewMessageListRowToolPillListRow.swift:36-42).
R15. **Sidebar rows run unbounded all-message queries for unread dots** (WindowsSidebarOpenRow.swift:26-31); add fetchLimit.
R16. **GroupCache mutates observed state during body evaluation** (ChatViewMessageList.swift:34,90-111).
R17. Onboarding step icons swap view types so the replace transition never animates (OnboardingViewStatusStep.swift:140-159).
R18. Body-error auto-resume has no backoff cap; double closeStream after result+EOF can double-fire toasts (pre-existing).

## Fixed (this pass, Linux daemon + macOS parity)

1. **Cold resume broken on Linux: session-id casing.** Runner lowercases the id for the CLI, JSONL replay looked up the raw uppercase id; on ext4 the file is never found and the finished turn is silently lost. Fixed in `SessionJSONLReplay.js`; same latent bug fixed in macOS `SessionJSONLReplay.swift` and `SessionHandler.swift` (case-sensitive APFS).
2. **Child stderr never drained.** The pipe fills (~64KB) and the claude CLI blocks mid-write: stream stalls forever with no exit envelope. Now logged in `Runner.js`.
3. **Any handler exception crashed the whole daemon.** A dangling symlink in a browsed directory (`statSync` ENOENT) killed every live stream. `HTTPServer.js` now contains handler failures as 500s; `FilesHandler.js` uses `throwIfNoEntry` and skips unreadable directories like macOS.
4. **`spawnSync` title generation froze the event loop.** Every live stream stopped flushing for the full sonnet call (seconds to tens of seconds), typically triggered mid-stream every 5 messages. `SessionHandler.runSonnet` is now async; router/server handle promise-returning handlers.
5. **Per-chunk UTF-8 decode corrupted multibyte text** (emoji/CJK split across a 64KB chunk boundary became U+FFFD, also poisoning ring replays). `Runner.js` now uses `StringDecoder`.
6. **Image-only messages 400'd on Linux** (`body?.prompt` truthiness rejects empty prompt; macOS accepts). Now `typeof === 'string'`.
7. **Restart race: two claude processes on one session.** `start` SIGINTed the old runner and spawned immediately; now the new spawn waits for the old process close, and abort escalates SIGINT → SIGKILL after 5s.
8. **Compacting envelope never emitted by Linux.** `Runner.ingest` now translates `system/informational/compacting` to `{type:"status",state:"compacting"}` like macOS, so the iOS compacting pill works on Linux.
9. **`+` in query values decoded as space on Linux only** (`URLSearchParams`), corrupting paths like `c++`. Now percent-decodes with raw fallback, matching macOS.
10. **>1MB request bodies were dropped with a raw socket destroy** (phone saw a connection reset). Now answers `413 payload_too_large`. The client half is still open, see #14.

## Open: high

11. **iOS: no stream ownership token** (`ChatService` keys everything by sessionId). Abort + re-send, deep-link send, or foreground resume racing a dying connection lets the stale stream's EOF tear down the new stream's state: split bubbles, lost partial text. Also `StreamingClient` streams are uncancellable (no `onTermination`, task handle dropped). `ChatService.swift:5-9,133-143,229-236`, `StreamingClient.swift:24-58`, `DeepLinkRouter.swift:90-93`.
12. **iOS: mid-stream drop while foregrounded never resumes.** Body-error catch leaves `isStreaming` true and schedules nothing; `resumeIfStuck` only fires on appear/scene-active, and the `activeStreams` guard races the dying stream. `ChatService.swift:58,251-257`, `ChatView.swift:35-51`.
13. **iOS: daemon error/exit events swallowed.** `.error` discards the message and closes with `isFailed: false`; nonzero `.exited` ignored. Failures render as a successful empty turn; the assistant "Failed" UI is dead code. `ChatService.swift:361-375`.
14. **Image uploads exceed the body cap.** iOS encodes full-resolution PNG base64; any camera photo blows past 1MB on both daemons. Downscale/JPEG on the client before encoding. `ChatService.swift:205-210`.
15. **Cold-resume replay duplicates the last turn.** JSONL replay restarts seq at 1 and ignores `after_seq`; client applies events unconditionally, duplicating already-persisted messages after a daemon restart. Daemon should honor `after_seq` in replay; client should dedupe. `ChatService.swift:224-226`, `SessionJSONLReplay.js:52-66`.
16. **Cold resume wipes visible partial text before replacement is confirmed**; empty resume stream then deletes the message entirely. `ChatService.swift:68-72,276-284`.
17. **Closing a window strands the session and its history forever** (nothing deletes sessions or their keyed rows; no UI lists non-open sessions). Product decision: recent-sessions list or cascade delete. `WindowActions.swift:59-71`.
18. **Deleting an endpoint leaves dangling `Session.endpoint` references** (no inverse relationships, no nullify). `EndpointActions.swift:41-45`, `Session.swift:10`.

## Open: medium

19. **iOS NDJSON framing uses `bytes.lines`**, which also splits on U+0085/U+2028/U+2029 that daemons do not escape; one such char in model output silently drops events. Frame on raw `\n` bytes. `StreamingClient.swift:45-46`.
20. **Retried message stuck in `.retrying` forever** if the retry stream dies before the first event. `ChatService.swift:251-257,89-90`.
21. **Ring eviction creates silent transcript gaps on resume** (1000-envelope ring vs per-token envelopes); client gets no gap marker. Needs a desync signal or JSONL backfill. `Runner.js:62-79`.
22. **`--dangerously-skip-permissions` on Linux only**; macOS runs without it. Policy decision, then align. `Runner.js:24`, `Runner.swift:36-56`.
23. **Git auto-refresh deletes `GitChange` rows under an open diff sheet** (deleted-model dereference). `GitActions.swift:32-34`, `GitView.swift:36-38`.
24. **`cloude://pair` deep link silently overwrites a stored endpoint token** without probe or confirmation. `DeepLinkRouter.swift:112-138`.
25. **Background windows never resume after relaunch**; only the focused session's `resumeIfStuck` runs, others spin forever. `WindowsView.swift:134-149`.
26. **GitHandler still uses `spawnSync`** (brief event-loop stalls on large diffs). `GitHandler.js:15-25`.

## Open: low

27. No subscriber backpressure cap (`Runner.js:119`); slow tunnel clients buffer unboundedly in daemon memory.
28. Image dropbox temp dirs never cleaned (`ImageDropbox.js:21-31`).
29. JSONL replay fabricates `exit code 0` and can replay the whole file when no user entry matches (`SessionJSONLReplay.js:26-35,64`).
30. macOS drops an unterminated trailing stdout line that Linux emits (`Runner.swift:246-252`).
31. Directory sort order and search depth differ between daemons (`FilesHandler.swift:25,66-69` vs `FilesHandler.js`).
32. Linux git log rows with tabs in subjects can fail whole-log Codable decode on iOS (`GitHandler.js:177-183`).
33. iOS minor unbounded growth: `ChatLiveStream.snapshot` insert-on-read, unpruned `lastSeqs`, dead `centerTabs`, unlimited message `@Query`.
34. Duplicate concurrent git refresh on session open (`GitView.swift:29-35` + `SessionView.swift:28-32`).
