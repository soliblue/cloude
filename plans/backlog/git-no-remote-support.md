# Git No-Remote Support {arrow.triangle.branch}
<!-- priority: 7 -->
<!-- tags: git -->

> Git status currently relies on `origin/HEAD`, which fails for repos without a remote. Use `git status -sb` and parse ahead/behind from status. Add staged vs unstaged diffs and rename handling.

**Files:** `GitService.swift`
