# Fix: Git diff infinite loading on Linux relay

## Bug
Tapping a file in the git tab showed infinite loading spinner. The `git_diff_result` response was returning the repo root path instead of the file path, so the iOS path matching never succeeded.

## Fix
`handlers-git.js`: changed `path` to `file || path` in the `git_diff_result` response.
