# Git feature (read-only, v1)

## Goal

The Git tab in `SessionView` shows the repo state for `session.path`: branch, ahead/behind, staged + unstaged changes. Tapping a change opens its unified diff as a sheet. Below the changes list, recent commits are shown.

Commit / stage / branch write operations are **out of scope for v1**. Confirmed by user.

## Product behavior

- **Tab visibility**: the Git tab is always present in `SessionViewTabs` but **disabled** (greyed, non-tappable) when `session.path` is not inside a git repo. Detected via `Session.hasGit: Bool` flag set from the first `/git/status` probe (404 / non-zero → false, valid payload → true). Keeps tab count constant across sessions, avoids UI jitter on path change.
- **Refresh**: pull-to-refresh on the status list. **Also auto-refresh on tab focus** (when `SessionView.activeTab` becomes `.git`).
- **Diff size**: soft clamp at 5000 lines server-side. If truncated, render a trailing "Diff truncated — 12,453 more lines" footer with a "Load full diff" button that re-fetches without the clamp. Protects the UI from locking on a 50k-line diff.
- **Binary files**: `git diff` emits `Binary files a/foo.png and b/foo.png differ`. Show a placeholder row ("Binary file, not shown") instead of parsing.
- **Empty repo / no commits**: dedicated empty state ("No commits yet"). Don't surface raw git errors.
- **Detached HEAD**: render `branch` as the short SHA; `ahead=0`, `behind=0`. Don't error.
- **Commit log**: infinite-scroll pagination, 50 per page, `git log --skip=N --max-count=50`.

## Architecture (v2 layout)

```
clients/ios/src/Features/Git/
  UI/
    GitView.swift                // git tab: branch header, ahead/behind counts, two grouped sections (Staged / Unstaged), list of GitViewChangeRow; bottom: commit list with infinite scroll; tap row → presents GitDiffSheet
    GitViewStatusHeader.swift    // branch pill + ahead/behind badges + total +/- counts
    GitViewChangeRow.swift       // status badge (color+letter), path, +/- counts, tap target
    GitViewCommitRow.swift       // short sha, subject, author, relative time
    GitViewEmptyRepo.swift       // "No commits yet" empty state
    GitDiffSheet.swift           // unified diff for one file (staged or unstaged); lightweight hunk parser
    GitDiffSheetBody.swift       // renders parsed hunks: header (@@), +/- lines tinted red/green, context neutral; HighlightSwift per file extension
    GitDiffSheetTruncatedFooter.swift // "Diff truncated — N more lines" + "Load full diff" button
    GitDiffSheetBinaryPlaceholder.swift // "Binary file, not shown"
  Logic/
    GitChangeType.swift          // enum: added/modified/deleted/renamed/copied/untracked/ignored/conflicted. Codable (String rawValue)
    GitChange.swift              // @Model: path, type: GitChangeType, isStaged, additions?, deletions?, status: GitStatus? (inverse)
    GitStatus.swift              // @Model: session: Session? (one per session, upserted), branch, ahead, behind, updatedAt, changes via @Relationship(deleteRule: .cascade)
    GitCommit.swift              // @Model: session: Session?, sha, author, date, subject
    GitStatusDTO.swift           // Decodable wire structs: GitChangeDTO, GitStatusDTO
    GitCommitDTO.swift           // Decodable wire structs: GitCommitDTO, GitLogDTO
    GitActions.swift             // stateless mutations: upsertStatus, replaceLog, appendLogPage, clear, setHasGit(Bool, on: Session)
    GitService.swift             // stateless; status/diff/log network I/O
```

`Session.hasGit: Bool` added to `Features/Sessions/Logic/Session.swift` (default true until probed; flip to false on 404).

Daemon side:
```
daemons/macos/src/Handlers/GitHandler.swift
  GET  /sessions/:id/git/status?path=…                            status()  // {branch, ahead, behind, changes:[...]}. 404 if path is not a git repo.
  GET  /sessions/:id/git/diff?path=…&file=…&staged=…&full=…       diff()    // raw unified diff, text/plain. Soft-clamp at 5000 lines unless full=1. Returns header "X-Diff-Truncated: <originalLines>" when clamped.
  GET  /sessions/:id/git/log?path=…&skip=…&count=…                log()     // {commits:[...]}
```

Handler shells out to `/usr/bin/git` via `Process`, `currentDirectoryURL = URL(fileURLWithPath: path)`. Private `runText(args:cwd:)` helper inside the handler.

## Port map (cloude-main → v2)

| cloude-main | v2 target | Notes |
|---|---|---|
| `Cloude Agent/Services/GitService.swift` status parse (porcelain + numstat merge) | `GitHandler.status()` | port as-is; rename for v2 style; drop `!!` ignored unless user asks for it |
| `Cloude Agent/Services/GitService.swift` log parse (`%h\t%s\t%an\t%aI`) | `GitHandler.log()` | add `--skip` / `--max-count` for pagination |
| `Cloude Agent/Services/GitService.swift` ahead/behind (`git rev-list --left-right --count origin/HEAD...HEAD`) | `GitHandler.status()` helper | guard for no-upstream / empty repo |
| `CloudeShared/Models/GitTypes.swift` | `GitStatusDTO.swift` + `GitStatus.swift` / `GitChange.swift` | old repo conflated wire + UI; v2 separates |
| `Features/Git/Services/GitRuntime.swift` caching | dropped | @Query on SwiftData replaces in-memory cache |
| `Features/Git/Views/GitChangesView.swift` + `+RepositoryStatus.swift` | `GitView.swift` + `GitViewStatusHeader.swift` | consolidate, ThemeTokens throughout |
| `Features/Git/Views/GitDiffView.swift` + `+Components.swift` | `GitDiffSheet.swift` + `GitDiffSheetBody.swift` | keep the hunk parser; render with HighlightSwift, colors from ThemeColor |
| `Features/Git/Views/GitCommitRow.swift` | `GitViewCommitRow.swift` | minor style pass |

## Step plan

1. **Daemon first** — `GitHandler.swift` with three routes + `runText` helper + guards for empty repo / detached HEAD / no upstream / binary diff / rename detection. Register in `Router.swift`. Verify with curl.
2. **Models + DTOs + Session.hasGit** — `GitChangeType`, `GitChange`, `GitStatus`, `GitCommit`, DTOs, `Session.hasGit`. Register new @Models in the ModelContainer in `iOSApp.swift`.
3. **Service + Actions** — `GitService` (status, diff with `full:` flag, log with pagination), `GitActions` (upsertStatus, replaceLog, appendLogPage, clear, setHasGit).
4. **UI** — `GitView` with pull-to-refresh + `.onChange(activeTab == .git)` auto-refresh; two change sections; infinite-scroll commit list; tap row → `GitDiffSheet`. Header, rows, empty-repo state. Diff sheet renders hunks, binary placeholder, truncated footer.
5. **Tab wiring** — `SessionView`'s `.git` case → `GitView(session: session)`. `SessionViewTabs` reads `session.hasGit` and disables the `.git` pill when false (greyed, tap is a no-op). Probe `hasGit` on first tab render / session load.
6. **Tester** — scenarios `git-status.md`, `git-diff.md`, `git-tab-disabled-when-no-repo.md`. Deep link `cloude://session/tab?value=git` already exists. Perf interval `git.status.ms` for regression tracking.

## Gotchas to handle (old repo didn't)

- **Binary files in diff** — detect `Binary files X and Y differ`, render placeholder row.
- **Huge diffs** — soft-clamp 5000 lines, "Load full diff" escape hatch.
- **Rename detection** — pass `-M` to `git status --porcelain` so renames show as `R` not `D+??`.
- **Submodules** — show as a single row with type `.modified`; don't recurse.
- **Empty repo / no commits** — `git rev-list` errors; guard in `runText`, return ahead=0, behind=0, empty commits array, dedicated empty state.
- **Detached HEAD / no upstream** — branch = short sha, ahead=0, behind=0. Don't error.
- **Non-git path** — `git status` exit code 128 → handler returns 404 → iOS flips `Session.hasGit = false` → tab disables.

## Deep links (tester surface)

Existing `cloude://session/tab?value=git` sufficient. No new Git-specific deep links for v1.

## Out of scope for v1

- Staging / unstaging / committing / branch / merge / rebase / stash / conflict resolution.
- Full history beyond the paginated log view.
- Blame, per-line annotation.
