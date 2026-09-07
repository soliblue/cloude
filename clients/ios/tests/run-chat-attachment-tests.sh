#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
swiftc -parse-as-library -target "$(uname -m)-apple-macosx14.0" src/Features/Chat/Logic/ChatAttachmentService.swift tests/chat-attachments/ChatAttachmentTests.swift -o "$test_dir/chat-attachment-tests"
"$test_dir/chat-attachment-tests"
