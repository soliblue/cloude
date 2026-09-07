#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
swiftc -parse-as-library src/Features/Files/Logic/FileCSVService.swift tests/file-csv/FileCSVTests.swift -o "$test_dir/file-csv-tests"
"$test_dir/file-csv-tests"
