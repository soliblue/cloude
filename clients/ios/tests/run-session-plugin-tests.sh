#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
swiftc -O -parse-as-library -target "$(uname -m)-apple-macosx14.0" \
  src/Features/Sessions/Logic/SessionPlugin*.swift \
  src/Features/Sessions/Logic/SessionApp*.swift \
  src/Features/Sessions/Logic/SessionMcp*.swift \
  tests/session-plugins/*.swift -o "$test_dir/session-plugin-tests"
"$test_dir/session-plugin-tests"
