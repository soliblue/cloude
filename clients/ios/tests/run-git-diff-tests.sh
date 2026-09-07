#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
swiftc -parse-as-library src/Features/Git/Logic/GitDiffLine.swift tests/git-diff/GitDiffParserTests.swift -o "$test_dir/diff-tests"
"$test_dir/diff-tests"
