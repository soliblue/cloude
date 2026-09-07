#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
swiftc -parse-as-library -target "$(uname -m)-apple-macosx14.0" \
  src/Features/Sessions/Logic/Session.swift src/Features/Sessions/Logic/SessionTab.swift \
  src/Features/Sessions/Logic/SessionLogin*.swift \
  src/Features/Chat/Logic/Chat{Goal,Model,Provider,Effort,PermissionMode}.swift \
  tests/session-login/*.swift -o "$test_dir/session-login-tests"
"$test_dir/session-login-tests"
