# Fix Git Diff Loading Forever
<!-- build: 86 -->

Server returned repo path in gitDiffResult but client compared against file path, so they never matched and loading spinner never stopped.

Fixed by accepting any gitDiff event (only one diff sheet is open at a time anyway).

**Files:** `GitDiffView.swift`
