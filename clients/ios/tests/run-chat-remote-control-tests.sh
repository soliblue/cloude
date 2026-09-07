#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
swiftc -parse-as-library -target "$(uname -m)-apple-macosx14.0" \
  src/Features/Sessions/Logic/Session.swift src/Features/Sessions/Logic/SessionTab.swift src/Features/Sessions/Logic/Session+ConnectionScope.swift \
  src/Features/Chat/Logic/Chat{Goal,Model,Provider,Effort,PermissionMode,RemoteControlStore,RemoteControlService}.swift \
  tests/chat-remote-control/*.swift -o "$test_dir/chat-remote-control-tests"
"$test_dir/chat-remote-control-tests"
