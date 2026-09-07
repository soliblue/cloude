#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
swiftc -parse-as-library src/Features/Git/Logic/GitService.swift src/Features/Git/Logic/GitActions.swift src/Features/Git/Logic/GitCommit.swift src/Features/Git/Logic/GitCommitDTO.swift src/Features/Git/Logic/GitCommitDetailDTO.swift src/Features/Git/Logic/GitStatus.swift src/Features/Git/Logic/GitStatusDTO.swift src/Features/Git/Logic/GitChange.swift src/Features/Git/Logic/GitChangeType.swift src/Features/Git/Logic/GitDiffLine.swift src/Features/Endpoints/Logic/Endpoint.swift tests/git-service/*.swift -o "$test_dir/git-service-tests"
"$test_dir/git-service-tests"
