#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
swiftc src/Handlers/CodexControlHandler.swift src/Networking/HTTPResponse.swift src/Version.swift src/DaemonCapabilities.swift tests/control/*.swift -o "$test_dir/control-tests"
"$test_dir/control-tests"
