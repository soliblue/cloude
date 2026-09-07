#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
swiftc -O src/Features/Chat/Logic/ChatMarkdown{Block,InlineSegment,Parser,ParserBlocks,ParserInline,ParserInlineFormatting,ParserInlineRendering,StreamState}.swift \
  src/Features/Files/Logic/CloudeFileURL.swift tests/chat-markdown-stream/*.swift -o "$test_dir/chat-markdown-stream-tests"
"$test_dir/chat-markdown-stream-tests"
