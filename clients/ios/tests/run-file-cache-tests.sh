#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
swiftc -parse-as-library src/Features/Files/Logic/FileCache.swift src/Features/Files/Logic/FilePreviewTextService.swift tests/file-cache/main.swift -o "$test_dir/file-cache-tests"
"$test_dir/file-cache-tests"
