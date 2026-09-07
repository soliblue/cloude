#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
swiftc -parse-as-library -target "$(uname -m)-apple-macosx14.0" \
  src/Features/Sessions/Logic/Session.swift src/Features/Sessions/Logic/SessionActions+Worktree.swift \
  src/Features/Sessions/Logic/SessionTab.swift src/Features/Sessions/Logic/SessionWorktree*.swift \
  src/Features/Chat/Logic/Chat{Goal,Model,Provider,Effort,PermissionMode}.swift \
  tests/session-worktrees/*.swift -o "$test_dir/session-worktree-tests"
"$test_dir/session-worktree-tests"
