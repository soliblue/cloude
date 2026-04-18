# Git Log / Recent Commits {clock.arrow.circlepath}
<!-- priority: 8 -->
<!-- tags: git, ui, agent, relay -->
> Show recent commits in the git tab when the working tree is clean.

## Changes

- `GitCommit` model in CloudeShared
- `gitLog` client/server message pair across CloudeShared, Mac agent, and linux-relay
- `GitService.getLog` on the Mac agent
- `handleGitLog` on the linux-relay
- `GitChangesState` tracks `recentCommits`
- `GitChangesView` shows commit list when no staged/unstaged changes
- `GitCommitRow` renders individual commits with hash, message, author, relative date
- `ConnectionEvent.gitLog` and wiring through ConnectionManager+API and MessageHandler
