# Performance evidence

Measurements below are development checks, not physical-device guarantees.

## Simulator Git scrolling

On September 6, 2026, Instruments Time Profiler recorded the signed Debug build on iPhone 17 Pro Simulator, iOS 26.2. The 45.7-second run closed a file diff and scrolled the existing 86-commit fixture with three upward swipes. Commit rows advanced from the newest commit through commit 36. No potential hangs over the configured 250 ms threshold were recorded.

Artifacts:

- `/tmp/afto-git-scroll-2308.trace`
- `/tmp/afto-git-scroll-profile.xml`
- `/tmp/afto-git-scroll-hangs.xml`
- `/tmp/afto-git-scroll-summary.json`

The app debug library UUID was `D955A248-C098-354F-B347-4DD4A981968C`. App functions were symbolicated, with one unnamed app frame accounting for one sample. The trace contains 8,399 weighted samples. App-owned work other than the entry point was small; accessibility inspection from the automation tools is prominent. This run is useful for hang detection and locating unexpected app work, not a clean frame-rate or power benchmark. There is no comparable baseline trace, so no speedup percentage is claimed.

`clients/ios/scripts/summarize-time-profile.py` reads an Instruments `time-profile` XML export and reports per-thread sample weights and inclusive app stacks. The weights are sampled observations, not wall-clock latency.

## Long conversation scrolling

On September 7, 2026, an isolated local HTTP fixture imported 1,500 completed messages and 500 tools across 500 turns, including 100-line code blocks, tables, lists, and Unicode. The original unbounded lazy transcript could open blank. Its data was intact: native scroll-to-top revealed the first messages.

The transcript now initially mounts the latest 50 role groups and loads earlier groups in pages of 50. The first visible group remains stable when older messages load or new messages arrive. The scroll layout resets for a different session, and its initial bottom anchor follows estimated-height corrections until scrolling, loading earlier messages, or a new-message anchor takes control.

Simulator verification covered a cold launch, switching between 30-message and 1,500-message conversations, opening the final response, loading earlier messages with the fixture server stopped, and scrolling both directions through cached code, lists, and tool rows. A subsequent real Luna response completed with all 60 numbered lines and its final marker visible; model metadata remained correct after switching away and back.

A 45-second Instruments Time Profiler run recorded 4,594 weighted samples, no unsymbolicated app frames, and no potential hangs over 250 ms. Accessibility automation contributes to the trace. This establishes a reproducible layout fix and hang check, not a physical-device frame-rate or memory guarantee.

Artifacts:

- `/tmp/afto-long-chat-fixed-0425.trace`
- `/tmp/afto-long-chat-fixed-0425-profile.xml`
- `/tmp/afto-long-chat-fixed-0425-hangs.xml`
- `/tmp/afto-long-chat-fixed-0425-summary.json`

## Deterministic stress checks

- Chat grouping consumes 20,000 entries and verifies output equivalence with the previous implementation. It removes quadratic array copying. Local optimized runs were below 1 ms, versus approximately 1.3 seconds for the previous algorithm.
- Task calls are now queried and reduced once per visible session list, instead of repeating a whole-session query in every historical assistant group. Groups share the resulting snapshot and keep independent expanded state.
- Task-list reconstruction with 20,000 creates plus 20,000 updates improved from approximately 420 ms to 13 ms after replacing repeated ID scans with indexes. Randomized update/delete/reset/reused-ID fixtures preserve exact output.
- Markdown streaming with 4,000 frozen blocks and 500 tail updates improved from approximately 310 ms to 116 ms after eliminating repeated frozen-array copies. Parser parity is checked at every fixture character, including Unicode, code, lists, tables and full replacements.
- File tree expansion checks 20,000 files, stable identities, collapse, offline preservation, and deletion refresh. Local Debug checks were approximately 35 to 45 ms.
- Transport checks 20,000 NDJSON events, Unicode crossing byte boundaries, a final record without a newline, HTTP errors, and cancellation. Byte assembly runs outside MainActor.
- Native Codex journal checks 12,000 events, bounded replay batches, exact sequence suffixes, daemon restart, and replacing one turn without invalidating an existing reader.

These checks measure algorithms and correctness independently from SwiftUI rendering. Further work should profile a long live chat while scrolling and validate large media, memory, energy use, and accessibility on a physical iPhone.
