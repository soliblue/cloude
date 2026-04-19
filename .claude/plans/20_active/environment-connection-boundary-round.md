# Round: EnvironmentConnection boundary verification

## Plan
- Scope: env-scoped ownership for 2+ connected environments in iOS for Files tab, EnvironmentFolderPicker, file preview, Git tab status and diff, and input-bar @ file suggestions.
- Reproduction: connect two distinct environments with different repos, bind separate windows to each, then alternate windows while exercising file browsing, preview, git, diff, deep links, and @ file search.
- Scenarios: multi-env-file-routing, folder-browse-and-preview, git-status-and-diff-routing, at-file-search-routing, disconnected-fallback-check.
- Target metrics: zero cross-environment request and response mismatches, one expected file or git completion per user action, no stale inactive-window UI, and clean disconnected behavior with no fallback to another environment.
- Instrumentation: existing app-debug logging in EnvironmentConnection request and response paths is sufficient.

## Baseline
Pending

## Hypothesis
Pending

## Implementation
Completed: moved file, git, and file search response state onto EnvironmentConnection, removed their ConnectionEvent fanout, unified turn dispatch, and preserved queued attachment payloads for replay.

## After
Pending

## Verdict
Pending
