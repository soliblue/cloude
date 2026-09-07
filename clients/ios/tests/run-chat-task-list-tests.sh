#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
swiftc -O src/Features/Chat/Logic/ChatTaskList.swift src/Features/Chat/Logic/ChatTodoItem.swift tests/chat-task-list/*.swift -o "$test_dir/chat-task-list-tests"
"$test_dir/chat-task-list-tests"
