#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
swiftc -parse-as-library -target "$(uname -m)-apple-macosx14.0" src/Core/Networking/StreamingClient.swift tests/streaming-client/*.swift -o "$test_dir/streaming-client-tests"
"$test_dir/streaming-client-tests"
