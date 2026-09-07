#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
swiftc -parse-as-library -target "$(uname -m)-apple-macosx14.0" \
  src/Features/Terminal/Logic/Terminal{Snapshot,Event,Input,Store,SessionStore,Service,Page,Error}.swift \
  tests/terminal/*.swift -o "$test_dir/terminal-tests"
"$test_dir/terminal-tests"
