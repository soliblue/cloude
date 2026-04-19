# Round: runtime routing regression check

## Plan

### Goal
Verify that the current refactor still resolves the active window's environment and working directory correctly, and that multi-environment routing remains correct across file search, file browsing and preview, and git status and diff.

### Scenarios
- `at-file-search-routing`
- `folder-browse-and-preview`
- `git-status-and-diff-routing`

### Why these scenarios
- `at-file-search-routing` checks active-window runtime resolution and catches stale working-directory or environment fallback bugs.
- `folder-browse-and-preview` checks that directory listing and preview stay bound to the selected environment after switching.
- `git-status-and-diff-routing` checks git runtime routing, repo ownership, and diff freshness after switching.

### Target Metrics
- Every file search, directory, file, git status, and git diff request in `app-debug.log` uses the expected environment id with no cross-environment mismatches.
- The first request after each explicit environment switch reroutes correctly without extra taps or relaunch.
- `@file` suggestions remain scoped to the active working directory.
- File browsing and preview do not reuse stale content after a switch.
- Git status and diff do not reuse stale repo or diff content after a switch.

### Launcher
Use `count=2`.
