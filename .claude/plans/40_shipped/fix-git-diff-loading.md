---
title: "Fix Git Diff Loading Forever"
description: "Fixed git diff loading spinner never stopping due to path mismatch between server and client."
created_at: 2026-03-15
tags: ["git", "ui"]
icon: arrow.clockwise
build: 86
---


# Fix Git Diff Loading Forever {arrow.clockwise}
Server returned repo path in gitDiffResult but client compared against file path, so they never matched and loading spinner never stopped.

Fixed by accepting any gitDiff event (only one diff sheet is open at a time anyway).

**Files:** `GitDiffView.swift`
