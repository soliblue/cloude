#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
swiftc src/Features/Chat/Logic/ChatAgentAttention.swift src/Features/Chat/Logic/ChatInteractionQuestion.swift src/Features/Chat/Logic/ChatInteraction.swift src/Features/Chat/Logic/ChatInteractionStore.swift src/Features/Chat/Logic/ChatStreamEvent.swift src/Features/Chat/Logic/ChatToolResult.swift tests/chat-wire/main.swift -o "$test_dir/chat-wire-tests"
"$test_dir/chat-wire-tests"
