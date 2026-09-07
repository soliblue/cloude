#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
swiftc -parse-as-library src/CodexCompactionService.swift src/CodexCompactionState.swift src/CodexSubscriptionPolicy.swift tests/compaction/*.swift -o "$test_dir/compaction-tests"
"$test_dir/compaction-tests"
