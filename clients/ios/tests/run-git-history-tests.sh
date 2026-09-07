#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
swiftc -parse-as-library src/Features/Git/Logic/GitActions.swift src/Features/Git/Logic/GitCommit.swift src/Features/Git/Logic/GitCommitDTO.swift src/Features/Git/Logic/GitStatus.swift src/Features/Git/Logic/GitStatusDTO.swift src/Features/Git/Logic/GitChange.swift src/Features/Git/Logic/GitChangeType.swift tests/git-history/GitHistoryTests.swift -o "$test_dir/git-history-tests"
"$test_dir/git-history-tests"
