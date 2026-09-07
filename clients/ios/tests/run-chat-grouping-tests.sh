#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
swiftc -O src/Features/Chat/Logic/ChatMessageGroup.swift src/Features/Chat/Logic/ChatMessageGroupStore.swift src/Features/Chat/Logic/ChatMessageSegment.swift tests/chat-grouping/main.swift -o "$test_dir/chat-grouping-tests"
"$test_dir/chat-grouping-tests"
