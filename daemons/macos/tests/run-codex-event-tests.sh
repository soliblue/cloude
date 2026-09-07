#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../../.."
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
swiftc -parse-as-library daemons/macos/src/CodexEvent.swift \
  clients/ios/src/Features/Chat/Logic/Chat{StreamEvent,ToolResult,Interaction,InteractionQuestion}.swift \
  daemons/macos/tests/codex-events/*.swift -o "$test_dir/codex-event-tests"
"$test_dir/codex-event-tests"
