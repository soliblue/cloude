#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
swiftc -parse-as-library -swift-version 6 -warnings-as-errors -default-isolation MainActor \
  src/Features/Chat/Logic/ChatHistoryWindow.swift tests/history-window/Main.swift \
  -o "$test_dir/history-window-tests"
"$test_dir/history-window-tests"
