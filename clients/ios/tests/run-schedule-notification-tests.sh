#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
swiftc -parse-as-library -target "$(uname -m)-apple-macosx14.0" \
  src/Features/Chat/Logic/ChatNotification{Route,Delegate}.swift \
  src/Features/Chat/Logic/ChatProvider.swift \
  src/Features/Windows/Logic/WindowsScheduleNotification.swift \
  tests/schedule-notification/*.swift -o "$test_dir/notification-tests"
"$test_dir/notification-tests"
