#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
swiftc src/DaemonLifecycle.swift src/CodexClient.swift tests/CodexRequestsTests.swift -o "$test_dir/requests-tests"
CODEX_HOME="$test_dir/home" "$test_dir/requests-tests" "$PWD/tests/fake-codex-requests.py" "$test_dir/home"
