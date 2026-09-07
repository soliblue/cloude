#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
swiftc -parse-as-library -target "$(uname -m)-apple-macosx14.0" \
  src/Features/Sessions/Logic/Session.swift src/Features/Sessions/Logic/SessionActions+Location.swift \
  src/Features/Sessions/Logic/Session{Tab,Project,ProjectRoot,ProjectPage,ProjectStore,ProjectService}.swift \
  src/Features/Chat/Logic/Chat{Goal,Model,Provider,Effort,PermissionMode}.swift \
  tests/session-projects/*.swift -o "$test_dir/session-project-tests"
"$test_dir/session-project-tests"
