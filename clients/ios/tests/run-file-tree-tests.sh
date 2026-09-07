#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
swiftc -parse-as-library src/Features/Files/Logic/FileNodeDTO.swift src/Features/Files/Logic/FileTreeEntry.swift src/Features/Files/Logic/FileTreeStore.swift src/Features/Files/Logic/FileTreeActions.swift tests/file-tree/FileTreeTests.swift -o "$test_dir/file-tree-tests"
"$test_dir/file-tree-tests"
