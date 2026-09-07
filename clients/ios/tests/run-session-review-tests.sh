#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
swiftc -parse-as-library -target "$(uname -m)-apple-macosx14.0" \
  src/Features/Sessions/Logic/Session.swift src/Features/Sessions/Logic/SessionTab.swift \
  src/Features/Sessions/Logic/SessionReview*.swift src/Features/Sessions/Logic/SessionWorktree{Store,Branch,Branches,Result}.swift \
  src/Features/Chat/Logic/Chat{Goal,Model,Provider,Effort,PermissionMode,Message,Reference,ReviewKind,ReviewTarget}.swift \
  tests/session-review/*.swift -o "$test_dir/session-review-tests"
"$test_dir/session-review-tests"
