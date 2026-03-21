# Rich Tool Rendering — Phase 2: Result Previews {text.below.photo}
<!-- priority: 10 -->
<!-- tags: tool-pill, ui -->
<!-- build: 56 -->

> Added brief result summaries as second lines on completed tool pills.

Show brief result summary as a second line on completed tool pills:
- `↳ 241 lines` for Read
- `↳ Build Succeeded` for xcodebuild
- `↳ 12 matches in 4 files` for Grep
- `↳ ✓` for Edit/Write success
- `↳ ✗ old_string not found` for Edit errors (red tint)

Truncated to 40 chars. Implemented end-to-end: agent sends summaries → iOS stores → UI renders.
