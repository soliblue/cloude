#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
swiftc -parse-as-library -default-isolation MainActor -target "$(uname -m)-apple-macosx14.0" \
  src/Features/Chat/Logic/ChatImageGeneration.swift tests/chat-image/*.swift -o "$test_dir/image-tests"
"$test_dir/image-tests"
