# Fix Git Diff Loading Forever {arrow.clockwise}
<!-- priority: 10 -->
<!-- tags: git, ui -->
<!-- build: 86 -->

> Fixed git diff loading spinner never stopping due to path mismatch between server and client.

Server returned repo path in gitDiffResult but client compared against file path, so they never matched and loading spinner never stopped.

Fixed by accepting any gitDiff event (only one diff sheet is open at a time anyway).

**Files:** `GitDiffView.swift`
