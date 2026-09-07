#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
swiftc -parse-as-library src/GitProcess.swift src/GitWorktreeService.swift src/CodexSessionStore.swift tests/GitWorktreeTests.swift -o "$test_dir/worktree-tests"
"$test_dir/worktree-tests"
